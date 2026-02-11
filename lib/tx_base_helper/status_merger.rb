module TxBaseHelper
  class StatusMerger
    attr_reader :from_status, :to_status, :from_id, :to_id

    def initialize(from_id, to_id)
      @from_id = from_id.to_i
      @to_id   = to_id.to_i

      raise ArgumentError, "FROM and TO must be different" if @from_id == @to_id

      @from_status = IssueStatus.find(@from_id)
      @to_status   = IssueStatus.find(@to_id)
    end

    # 영향 범위 미리보기 (DRY RUN 역할)
    def preview
      counts = {}

      counts[:issues] = Issue.where(status_id: from_id).count

      jd_scope = JournalDetail.where(property: 'attr', prop_key: 'status_id')
      counts[:jd_old_value] = jd_scope.where(old_value: from_id.to_s).count
      counts[:jd_value]     = jd_scope.where(value: from_id.to_s).count

      counts[:noop_details] = jd_scope.where(
        "( old_value = :from AND value = :to ) OR " \
        "( old_value = :to AND value = :from ) OR " \
        "( old_value = :from AND value = :from )",
        from: from_id.to_s, to: to_id.to_s
      ).count

      counts[:wf_old] = WorkflowTransition.where(old_status_id: from_id).count
      counts[:wf_new] = WorkflowTransition.where(new_status_id: from_id).count

      counts[:wp_old] = WorkflowPermission.where(old_status_id: from_id).count
      counts[:wp_new] = WorkflowPermission.where(new_status_id: from_id).count

      counts[:trackers] = Tracker.where(default_status_id: from_id).count

      counts[:queries] = find_affected_query_ids.size

      commit_keywords = Setting.commit_update_keywords
      counts[:commit_keywords] = 0
      if commit_keywords.is_a?(Array)
        counts[:commit_keywords] = commit_keywords.count { |r| r.is_a?(Hash) && r['status_id'] == from_id.to_s }
      end

      if tx_localizations_available?
        counts[:tx_loc] = TxLocalization.where(localizable_type: 'IssueStatus', localizable_id: from_id).count
      end

      counts[:is_closed_mismatch] = from_status.is_closed != to_status.is_closed

      counts
    end

    # 병합 실행
    def execute!
      counts = preview

      ActiveRecord::Base.transaction do
        merge_issues(counts)
        merge_journal_details(counts)
        merge_workflow_transitions(counts)
        merge_workflow_permissions(counts)
        merge_trackers(counts)
        merge_queries(counts)
        merge_commit_keywords(counts)
        merge_tx_localizations(counts)
        delete_from_status
      end

      counts
    end

    def from_name
      from_status.respond_to?(:original_name) ? from_status.original_name : from_status.name
    end

    def to_name
      to_status.respond_to?(:original_name) ? to_status.original_name : to_status.name
    end

    private

    # STI 를 우회하여 직접 SQL 로 쿼리 필터를 검색
    def find_affected_query_ids
      rows = ActiveRecord::Base.connection.select_all(
        "SELECT id, filters FROM #{Query.table_name} WHERE filters LIKE '%status_id%'"
      )

      status_filter_keys = ['status_id', 'issue.status_id']
      ids = []

      rows.each do |row|
        filters = YAML.safe_load(row['filters'], permitted_classes: [Symbol, Hash, Array]) rescue next
        next unless filters.is_a?(Hash)
        status_filter_keys.each do |key|
          filter = filters[key]
          next unless filter.is_a?(Hash) && filter['values'].is_a?(Array)
          if filter['values'].include?(from_id.to_s)
            ids << row['id'].to_i
            break
          end
        end
      end

      ids
    end

    def tx_localizations_available?
      ActiveRecord::Base.connection.table_exists?('tx_localizations')
    end

    def merge_issues(counts)
      return unless counts[:issues] > 0

      Issue.where(status_id: from_id).update_all(status_id: to_id)

      # is_closed 불일치 시 closed_on 보정
      if from_status.is_closed != to_status.is_closed
        if to_status.is_closed? && !from_status.is_closed?
          Issue.where(status_id: to_id, closed_on: nil).update_all("closed_on = updated_on")
        elsif from_status.is_closed? && !to_status.is_closed?
          Issue.where(status_id: to_id).where.not(closed_on: nil).update_all(closed_on: nil)
        end
      end

      # done_ratio 보정 (status 기반 done_ratio 사용 시)
      if Issue.use_status_for_done_ratio? &&
         from_status.default_done_ratio != to_status.default_done_ratio
        Issue.where(status_id: to_id, done_ratio: from_status.default_done_ratio)
             .update_all(done_ratio: to_status.default_done_ratio)
      end
    end

    def merge_journal_details(counts)
      jd_scope = JournalDetail.where(property: 'attr', prop_key: 'status_id')

      if counts[:jd_old_value] > 0
        jd_scope.where(old_value: from_id.to_s).update_all(old_value: to_id.to_s)
      end

      if counts[:jd_value] > 0
        jd_scope.where(value: from_id.to_s).update_all(value: to_id.to_s)
      end

      # Remove no-op journal details (old_value == value after merge)
      if counts[:noop_details] > 0
        noop_ids = jd_scope.where("old_value = value AND value = ?", to_id.to_s).pluck(:id)
        orphan_journal_ids = jd_scope.where(id: noop_ids).pluck(:journal_id).uniq

        JournalDetail.where(id: noop_ids).delete_all

        # 빈 journal 정리
        Journal.where(id: orphan_journal_ids).find_each do |journal|
          next if journal.details.any?
          next if journal.notes.present?
          journal.destroy
        end
      end
    end

    def merge_workflow_transitions(counts)
      # 머지 전 기존 to_id self-transition 보존을 위해 ID 수집
      existing_self_transition_ids = WorkflowTransition
        .where(old_status_id: to_id, new_status_id: to_id).pluck(:id)

      # old_status_id 변환
      WorkflowTransition.where(old_status_id: from_id).find_each do |wf|
        existing = WorkflowTransition.find_by(
          tracker_id: wf.tracker_id, role_id: wf.role_id,
          old_status_id: to_id, new_status_id: wf.new_status_id,
          author: wf.author, assignee: wf.assignee,
          type: wf.type
        )
        if existing
          wf.destroy
        else
          wf.update_columns(old_status_id: to_id)
        end
      end

      # new_status_id 변환
      WorkflowTransition.where(new_status_id: from_id).find_each do |wf|
        existing = WorkflowTransition.find_by(
          tracker_id: wf.tracker_id, role_id: wf.role_id,
          old_status_id: wf.old_status_id, new_status_id: to_id,
          author: wf.author, assignee: wf.assignee,
          type: wf.type
        )
        if existing
          wf.destroy
        else
          wf.update_columns(new_status_id: to_id)
        end
      end

      # 머지로 새로 생긴 self-transition 만 정리 (기존 것 보존)
      WorkflowTransition
        .where(old_status_id: to_id, new_status_id: to_id)
        .where.not(id: existing_self_transition_ids)
        .destroy_all
    end

    def merge_workflow_permissions(counts)
      WorkflowPermission.where(old_status_id: from_id).find_each do |wp|
        existing = WorkflowPermission.find_by(
          tracker_id: wp.tracker_id, role_id: wp.role_id,
          old_status_id: to_id, new_status_id: wp.new_status_id,
          field_name: wp.field_name, rule: wp.rule,
          author: wp.author, assignee: wp.assignee,
          type: wp.type
        )
        if existing
          wp.destroy
        else
          wp.update_columns(old_status_id: to_id)
        end
      end

      WorkflowPermission.where(new_status_id: from_id).find_each do |wp|
        existing = WorkflowPermission.find_by(
          tracker_id: wp.tracker_id, role_id: wp.role_id,
          old_status_id: wp.old_status_id, new_status_id: to_id,
          field_name: wp.field_name, rule: wp.rule,
          author: wp.author, assignee: wp.assignee,
          type: wp.type
        )
        if existing
          wp.destroy
        else
          wp.update_columns(new_status_id: to_id)
        end
      end
    end

    def merge_trackers(counts)
      return unless counts[:trackers] > 0
      Tracker.where(default_status_id: from_id).update_all(default_status_id: to_id)
    end

    def merge_queries(counts)
      return unless counts[:queries] > 0

      status_filter_keys = ['status_id', 'issue.status_id']
      affected_ids = find_affected_query_ids

      affected_ids.each do |qid|
        row = ActiveRecord::Base.connection.select_one(
          "SELECT filters FROM #{Query.table_name} WHERE id = #{qid.to_i}"
        )
        next unless row

        filters = YAML.safe_load(row['filters'], permitted_classes: [Symbol, Hash, Array])
        next unless filters.is_a?(Hash)

        changed = false
        status_filter_keys.each do |key|
          filter = filters[key]
          next unless filter.is_a?(Hash) && filter['values'].is_a?(Array)
          if filter['values'].include?(from_id.to_s)
            filter['values'].map! { |v| v == from_id.to_s ? to_id.to_s : v }
            filter['values'].uniq!
            changed = true
          end
        end

        if changed
          ActiveRecord::Base.connection.execute(
            "UPDATE #{Query.table_name} SET filters = #{ActiveRecord::Base.connection.quote(YAML.dump(filters))} WHERE id = #{qid.to_i}"
          )
        end
      end
    end

    def merge_commit_keywords(counts)
      return unless counts[:commit_keywords] > 0

      keywords = Setting.commit_update_keywords
      keywords.each do |rule|
        next unless rule.is_a?(Hash)
        rule['status_id'] = to_id.to_s if rule['status_id'] == from_id.to_s
      end
      Setting.commit_update_keywords = keywords
    end

    def merge_tx_localizations(counts)
      return unless tx_localizations_available? && counts[:tx_loc].to_i > 0
      TxLocalization.where(localizable_type: 'IssueStatus', localizable_id: from_id).destroy_all
    end

    def delete_from_status
      from_status.destroy!
    end
  end
end
