module TxBaseHelper
  ISSUE_MEMO_FIELD_FORMATS = %w[string text].freeze

  def self.config_arr(key)
    Setting[:plugin_redmine_tx_0_base][key].to_s.tr('[]"','').split(',').map(&:to_i)
  end

  def self.config(key)
    Setting[:plugin_redmine_tx_0_base][key]
  end

  def self.issue_memo_custom_fields
    IssueCustomField.where(field_format: ISSUE_MEMO_FIELD_FORMATS).sorted.to_a
  end

  def self.issue_memo_custom_field
    field_id = config(:issue_memo_custom_field_id).to_i
    return nil if field_id <= 0

    issue_memo_custom_fields.find { |field| field.id == field_id }
  end

  def self.issue_memo_custom_field_for(issue, user = User.current)
    return nil unless issue
    return nil unless issue.attributes_editable?(user)

    field = issue_memo_custom_field
    return nil unless field
    return nil unless issue.editable_custom_fields(user).any? { |candidate| candidate.id == field.id }

    field
  end

  def self.issue_memos_for(issue_ids, user = User.current)
    return {} unless issue_memo_custom_field

    ids = Array(issue_ids).map(&:to_i).select(&:positive?).uniq
    return {} if ids.empty?

    Issue.visible.where(id: ids)
         .preload(:project, :tracker, custom_values: :custom_field)
         .each_with_object({}) do |issue, memos|
      memo = issue.memo(user)
         memos[issue.id] = memo if memo.present?
    end
  end

  def self.version_delay_reset?(old_version_id, new_version_id, cache = nil)
    old_effective_date = version_effective_date(old_version_id, cache)
    new_effective_date = version_effective_date(new_version_id, cache)

    old_effective_date.present? &&
      new_effective_date.present? &&
      new_effective_date > old_effective_date
  end

  def self.version_effective_date(version_id, cache = nil)
    normalized_id = normalize_version_id(version_id)
    return nil unless normalized_id

    if cache
      return cache[normalized_id] if cache.key?(normalized_id)

      cache[normalized_id] = Version.where(id: normalized_id).pick(:effective_date)
    else
      Version.where(id: normalized_id).pick(:effective_date)
    end
  end

  def self.normalize_version_id(version_id)
    return nil if version_id.blank?

    normalized_id = version_id.to_i
    normalized_id.positive? ? normalized_id : nil
  end

  # 일감 리스트 테이블용 헬퍼 메서드들
  # 컬럼 정렬 값 반환
  def get_column_sort_value(issue, column)
    case column
    when :project then issue.project.name
    when :tracker then issue.tracker.name
    when :status then issue.status.position
    when :priority then issue.priority.position
    when :fixed_version then issue.fixed_version_sort_value
    else
      issue.send(column)
    end
  end

  # 진행률 막대 렌더링
  def progress_bar(done_ratio)
    if done_ratio == 0
      "<table class='progress' style='width: 80px;'><tr><td class='todo' style='width: 100%;'></td></tr></table>".html_safe
    elsif done_ratio == 100
      "<table class='progress' style='width: 80px;'><tr><td class='closed' style='width: 100%;'></td></tr></table>".html_safe
    else
      "<table class='progress' style='width: 80px;'><tr><td class='closed' style='width: #{done_ratio}%;'></td><td class='todo' style='width: #{100 - done_ratio}%;'></td></tr></table>".html_safe
    end
  end

  # 컬럼 값 반환
  def get_column_value(issue, column)
    case column
    when :project then link_to_project(issue.project)
    when :subject then link_to(issue.subject, issue_path(issue), class: issue.css_classes, title: issue.subject)
    when :fixed_version then issue.fixed_version_plus
    when :done_ratio then progress_bar(issue.done_ratio)
    when :updated_on then format_time(issue.updated_on)
    when :start_date then format_date(issue.start_date)
    when :due_date then format_date(issue.due_date)
    when :first_due_date then issue.respond_to?(:first_due_date) ? format_date(issue.first_due_date) : nil
    when :tip then "<font color='red'>#{issue.tip}</font>".html_safe
    when :assigned_to then issue.assigned_to_id ? link_to_principal(issue.assigned_to) : ''
    when :estimated_hours then issue.estimated_hours_plus
    when :worker then issue.worker_id ? link_to_principal(issue.worker) : ''
    else
      issue.send(column)
    end
  end

  module_function :get_column_sort_value, :progress_bar, :get_column_value
  
  # 디스크 사용량 체크 메서드
  def self.check_disk_usage
    # Redmine이 설치된 디렉토리의 파티션 체크
    redmine_path = Rails.root.to_s
    
    # df 명령어로 파티션 정보 가져오기
    df_output = `df -h #{redmine_path} 2>/dev/null`.lines
    
    return nil if df_output.size < 2
    
    # 헤더 라인 건너뛰고 데이터 라인 파싱
    data_line = df_output[1].strip.split(/\s+/)
    
    # 데이터 형식: Filesystem Size Used Avail Capacity Mounted
    # 예: /dev/disk1s1 233Gi 150Gi 80Gi 66% /
    {
      filesystem: data_line[0],
      total: data_line[1],
      used: data_line[2],
      available: data_line[3],
      percent: data_line[4].to_i,
      mount: data_line[5] || '/'
    }
  rescue => e
    Rails.logger.error "Failed to check disk usage: #{e.message}"
    nil
  end

  module IssuePatch
    def self.included(base)
      base.class_eval do
        before_save :record_end_date_change_log
        belongs_to :end_date_delayed_by, class_name: 'User', optional: true
      end
    end

    def fixed_version_plus
      if self.fixed_version.present?
        "<span class='tag-label-color' style='background-color: #{get_version_color(self.fixed_version)}'>#{self.fixed_version}</span>".html_safe
      end
    end

    def estimated_hours_plus
      if self.estimated_hours.present?
        if estimated_hours >= 8 then
          "#{estimated_hours.to_i / 8}일"
        else
          "#{estimated_hours.to_i}시간"
        end
      else
        nil
      end
    end

    def fixed_version_sort_value
      if self.fixed_version.present?
        if self.fixed_version.effective_date
          self.fixed_version.effective_date.to_s + '|' + self.fixed_version.name
        else
          '9999-99-99' + '|' + self.fixed_version.name
        end
      end
    end

    def memo_custom_field
      field = TxBaseHelper.issue_memo_custom_field
      return nil unless field

      available_custom_fields.find { |candidate| candidate.id == field.id }
    end

    def memo_visible_custom_field(user = User.current)
      field = memo_custom_field
      return nil unless field

      visible_custom_field_values(user).find { |value| value.custom_field_id == field.id }&.custom_field
    end

    def memo(user = User.current)
      field = memo_visible_custom_field(user)
      field ? custom_field_value(field) : nil
    end

    def memo_present?(user = User.current)
      memo(user).present?
    end

    def memo_editable?(user = User.current)
      field = memo_custom_field
      return false unless field
      return false unless attributes_editable?(user)

      editable_custom_fields(user).any? { |candidate| candidate.id == field.id }
    end

    def memo=(value)
      field = memo_custom_field
      return value unless field

      self.custom_field_values = { field.id.to_s => value.to_s }
      value
    end

    def update_memo!(value, user: User.current)
      return false unless memo_editable?(user)

      init_journal(user)
      send(:safe_attributes=, {
        'custom_field_values' => { memo_custom_field.id.to_s => value.to_s }
      }, user)
      save
    end

    private

    def get_version_color(version)
      return "#ccc" unless version.effective_date
      return "#900" if version.effective_date < Date.today
      grade = [0, (version.effective_date - Date.today).to_i / 12].max
      case grade
      when 0
        "#099"  # 기한 임박
      when 1
        "#4bb"  # 여유 있음
      when 2
        "#8bb"  # 충분한 시간
      else
        "#bbb"  # 기타
      end
    end

    def record_end_date_change_log
      reset_due_date_baseline = milestone_due_date_reset_required?

      if reset_due_date_baseline
        reset_first_due_date_baseline!
        clear_end_date_delay_tracking!
      end

      # 완료 기한이 변경된 경우
      if respond_to?(:due_date_changed?) && due_date_changed?
        now = Time.current
        self.end_date_changed_on = now

        unless reset_due_date_baseline
          preserve_first_due_date!

          # 완료 기한이 뒤로 밀린 경우 (지연)
          # due_date_was: 변경 전 날짜, due_date: 변경 후 날짜
          # 작업 시작 이후(진척도 > 0 또는 상태가 진행중 이상)에만 지연으로 기록
          if due_date_was.present? && due_date.present? && due_date > due_date_was && work_started_at?(now)
            self.end_date_delayed_on = now
            self.end_date_delayed_by_id = User.current.id  # 일정 수정 조작자
            self.end_date_delayed_days = TxBaseHelper.business_days_between(due_date_was, due_date)
          end
        end
      end
    end

    public

    # 특정 시점에서의 진척도를 계산
    # 일감 생성 시점부터 해당 시점까지의 done_ratio 변경 이력을 추적
    def done_ratio_at(target_time)
      # 생성 시점부터 target_time까지의 done_ratio 변경 이력을 시간순으로 조회
      done_ratio_journals = journals.reorder(created_on: :asc)
                                    .joins(:details)
                                    .where(journal_details: { prop_key: 'done_ratio' })
                                    .where('journals.created_on <= ?', target_time)

      # 초기값 결정: 첫 번째 done_ratio 변경 저널의 old_value가 생성 시점의 값
      # 변경 이력이 없으면 현재 done_ratio가 초기값 (생성 후 변경 없음)
      first_change = journals.reorder(created_on: :asc)
                             .joins(:details)
                             .where(journal_details: { prop_key: 'done_ratio' })
                             .first

      if first_change
        first_detail = first_change.details.find { |d| d.prop_key == 'done_ratio' }
        ratio = first_detail&.old_value.to_i
      else
        # done_ratio 변경 기록이 없으면 현재 값이 초기값
        ratio = done_ratio
      end

      # target_time까지의 변경 이력 적용
      done_ratio_journals.each do |journal|
        detail = journal.details.find { |d| d.prop_key == 'done_ratio' }
        ratio = detail.value.to_i if detail&.value.present?
      end

      ratio
    end

    # 특정 시점에서의 상태 ID를 계산
    # 일감 생성 시점부터 해당 시점까지의 status_id 변경 이력을 추적
    def status_at(target_time)
      # 생성 시점부터 target_time까지의 status_id 변경 이력을 시간순으로 조회
      status_journals = journals.reorder(created_on: :asc)
                                .joins(:details)
                                .where(journal_details: { prop_key: 'status_id' })
                                .where('journals.created_on <= ?', target_time)

      # 초기값 결정: 첫 번째 status_id 변경 저널의 old_value가 생성 시점의 값
      # 변경 이력이 없으면 현재 status_id가 초기값 (생성 후 변경 없음)
      first_change = journals.reorder(created_on: :asc)
                             .joins(:details)
                             .where(journal_details: { prop_key: 'status_id' })
                             .first

      if first_change
        first_detail = first_change.details.find { |d| d.prop_key == 'status_id' }
        result_status_id = first_detail&.old_value.to_i
      else
        # status_id 변경 기록이 없으면 현재 값이 초기값
        result_status_id = status_id
      end

      # target_time까지의 변경 이력 적용
      status_journals.each do |journal|
        detail = journal.details.find { |d| d.prop_key == 'status_id' }
        result_status_id = detail.value.to_i if detail&.value.present?
      end

      result_status_id
    end

    # 특정 시점에 작업이 시작되었는지 확인
    # 조건: done_ratio > 0 또는 상태가 '진행중' 이상
    def work_started_at?(target_time)
      return true if done_ratio_at(target_time) > 0

      # IssueStatus의 stage 시스템 사용 (redmine_tx_advanced_issue_status)
      target_status_id = status_at(target_time)
      if IssueStatus.respond_to?(:is_in_progress?)
        IssueStatus.is_in_progress?(target_status_id) ||
          IssueStatus.is_in_review?(target_status_id) ||
          IssueStatus.is_implemented?(target_status_id) ||
          IssueStatus.is_qa?(target_status_id) ||
          IssueStatus.is_completed?(target_status_id)
      else
        false
      end
    end

    def update_end_date_changed_on!
      tracking_journals = due_date_tracking_journals
      last_change = tracking_journals.reverse.find do |journal|
        due_date_tracking_detail_for(journal, 'due_date').present?
      end
      tracking_state = rebuild_due_date_tracking_state(tracking_journals)

      updated_columns = {
        end_date_changed_on: last_change ? last_change.created_on : created_on,
        first_due_date: tracking_state[:first_due_date]
      }

      if tracking_state[:last_delay]
        updated_columns.merge!(
          end_date_delayed_on: tracking_state[:last_delay][:journal].created_on,
          end_date_delayed_by_id: tracking_state[:last_delay][:journal].user_id,  # 일정 수정 조작자
          end_date_delayed_days: TxBaseHelper.business_days_between(
            tracking_state[:last_delay][:old_date],
            tracking_state[:last_delay][:new_date]
          )
        )
      else
        # 작업 시작(진척도 > 0 또는 진행중 이상 상태) 후 지연이 없으면 nil로 초기화
        updated_columns.merge!(
          end_date_delayed_on: nil,
          end_date_delayed_by_id: nil,
          end_date_delayed_days: nil
        )
      end

      update_columns(updated_columns)
    end

    private

    def preserve_first_due_date!
      return unless respond_to?(:first_due_date) && respond_to?(:first_due_date=)
      return if first_due_date.present?

      self.first_due_date = due_date_was if due_date_was.present?
      self.first_due_date = due_date if first_due_date.blank? && due_date.present?
    end

    def reset_first_due_date_baseline!
      return unless respond_to?(:first_due_date) && respond_to?(:first_due_date=)

      self.first_due_date = due_date
    end

    def clear_end_date_delay_tracking!
      self.end_date_delayed_on = nil
      self.end_date_delayed_by_id = nil
      self.end_date_delayed_days = nil
    end

    def milestone_due_date_reset_required?
      return false unless respond_to?(:fixed_version_id_changed?) && fixed_version_id_changed?

      TxBaseHelper.version_delay_reset?(fixed_version_id_was, fixed_version_id)
    end

    def due_date_tracking_journals
      journals.reorder(created_on: :asc, id: :asc)
              .joins(:details)
              .where(journal_details: { prop_key: %w[due_date fixed_version_id] })
              .distinct
              .preload(:details)
              .to_a
    end

    def rebuild_due_date_tracking_state(tracking_journals)
      current_due_date = initial_due_date_from_history(tracking_journals)
      current_fixed_version_id = initial_fixed_version_id_from_history(tracking_journals)
      tracked_first_due_date = current_due_date
      last_delay = nil

      tracking_journals.each do |journal|
        due_date_detail = due_date_tracking_detail_for(journal, 'due_date')
        fixed_version_detail = due_date_tracking_detail_for(journal, 'fixed_version_id')
        next unless due_date_detail || fixed_version_detail

        new_due_date = due_date_detail ? parse_due_date_value(due_date_detail.value) : current_due_date
        new_fixed_version_id = fixed_version_detail ? parse_version_id_value(fixed_version_detail.value) : current_fixed_version_id
        baseline_reset_applied = fixed_version_detail.present? &&
                                 TxBaseHelper.version_delay_reset?(current_fixed_version_id, new_fixed_version_id)

        if baseline_reset_applied
          tracked_first_due_date = new_due_date
          last_delay = nil
        elsif tracked_first_due_date.nil? && due_date_detail.present? && new_due_date.present?
          tracked_first_due_date = new_due_date
        end

        unless baseline_reset_applied
          if due_date_detail.present? &&
             current_due_date.present? &&
             new_due_date.present? &&
             new_due_date > current_due_date &&
             work_started_at?(journal.created_on)
            last_delay = {
              journal: journal,
              old_date: current_due_date,
              new_date: new_due_date
            }
          end
        end

        current_due_date = new_due_date if due_date_detail.present?
        current_fixed_version_id = new_fixed_version_id if fixed_version_detail.present?
      end

      {
        first_due_date: tracked_first_due_date,
        last_delay: last_delay
      }
    end

    def initial_due_date_from_history(tracking_journals)
      first_due_date_journal = tracking_journals.find do |journal|
        due_date_tracking_detail_for(journal, 'due_date').present?
      end
      return due_date unless first_due_date_journal

      parse_due_date_value(due_date_tracking_detail_for(first_due_date_journal, 'due_date').old_value)
    end

    def initial_fixed_version_id_from_history(tracking_journals)
      first_fixed_version_journal = tracking_journals.find do |journal|
        due_date_tracking_detail_for(journal, 'fixed_version_id').present?
      end
      return fixed_version_id unless first_fixed_version_journal

      parse_version_id_value(due_date_tracking_detail_for(first_fixed_version_journal, 'fixed_version_id').old_value)
    end

    def due_date_tracking_detail_for(journal, prop_key)
      journal.details.find { |detail| detail.prop_key == prop_key }
    end

    def parse_due_date_value(value)
      return nil if value.blank?
      return value.to_date if value.respond_to?(:to_date)

      Date.parse(value.to_s)
    rescue ArgumentError, TypeError
      nil
    end

    def parse_version_id_value(value)
      TxBaseHelper.normalize_version_id(value)
    end
  end

  # 두 날짜 사이의 영업일 수 계산 (주말/공휴일 제외)
  # @param start_date [Date] 시작 날짜 (이 날짜 다음날부터 계산)
  # @param end_date [Date] 종료 날짜 (이 날짜까지 계산)
  # @return [Integer] 영업일 수
  def self.business_days_between(start_date, end_date)
    return 0 if start_date >= end_date

    count = 0
    current_date = start_date + 1

    # 공휴일 캐시를 위해 날짜 범위 조회 (HolidayApi가 사용 가능한 경우)
    holidays = {}
    if HolidayApi.available?
      holidays = HolidayApi.for_date_range(start_date, end_date)
    end

    while current_date <= end_date
      # 토요일(6), 일요일(0) 제외
      unless current_date.wday == 0 || current_date.wday == 6
        # 공휴일 제외
        unless holidays.key?(current_date)
          count += 1
        end
      end
      current_date += 1
    end

    count
  end
end

unless Issue.included_modules.include?(TxBaseHelper::IssuePatch)
  Issue.send(:include, TxBaseHelper::IssuePatch)
end
