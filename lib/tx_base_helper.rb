module TxBaseHelper
  def self.config_arr(key)
    Setting[:plugin_redmine_tx_0_base][key].to_s.tr('[]"','').split(',').map(&:to_i)
  end

  def self.config(key)
    Setting[:plugin_redmine_tx_0_base][key]
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
      end
    end

    private
    
    def record_end_date_change_log
      # 완료 기한이 변경된 경우
      if respond_to?(:due_date_changed?) && due_date_changed?
        now = Time.now
        self.end_date_changed_on = now
        
        # 완료 기한이 뒤로 밀린 경우 (지연)
        # due_date_was: 변경 전 날짜, due_date: 변경 후 날짜
        if due_date_was.present? && due_date.present? && due_date > due_date_was
          self.end_date_delayed_on = now
        end
      end
    end

    public
    
    def update_end_date_changed_on!
      # 최신 저널부터 역순으로 탐색
      journals_with_due_date = journals.reorder(created_on: :desc).joins(:details).where(journal_details: { prop_key: 'due_date' })
      
      last_change = journals_with_due_date.first
      
      if last_change
        update_columns(end_date_changed_on: last_change.created_on)
      else
        update_columns(end_date_changed_on: created_on)
      end

      # 지연 발생 시각 찾기 (과거 이력 뒤지기)
      # 가장 최근에 '지연'이 발생했던 시점을 찾음
      last_delay_journal = nil
      
      journals_with_due_date.each do |journal|
        detail = journal.details.find { |d| d.prop_key == 'due_date' }
        old_value = detail.old_value
        new_value = detail.value
        
        # 날짜 비교를 위해 파싱 (String -> Date)
        begin
          old_date = old_value.present? ? Date.parse(old_value) : nil
          new_date = new_value.present? ? Date.parse(new_value) : nil
          
          if old_date && new_date && new_date > old_date
            last_delay_journal = journal
            break # 가장 최근의 지연 발견 시 중단
          end
        rescue ArgumentError
          # 날짜 파싱 실패 시 무시
        end
      end

      if last_delay_journal
        update_columns(end_date_delayed_on: last_delay_journal.created_on)
      end
    end
  end
end

unless Issue.included_modules.include?(TxBaseHelper::IssuePatch)
  Issue.send(:include, TxBaseHelper::IssuePatch)
end
