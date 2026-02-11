namespace :tx_base do
  desc <<~DESC
    Merge duplicate issue statuses (FROM → TO).
    Updates all references including issues, journals, workflows, and saved queries.

    Usage:
      rake tx_base:merge_status FROM=old_id TO=new_id [DRY_RUN=true]

    Examples:
      rake tx_base:merge_status FROM=7 TO=3 DRY_RUN=true   # Preview changes
      rake tx_base:merge_status FROM=7 TO=3                 # Execute merge
  DESC
  task merge_status: :environment do
    from_id = ENV['FROM'].to_i
    to_id   = ENV['TO'].to_i
    dry_run = ENV['DRY_RUN'].to_s.downcase == 'true'

    if from_id == 0 || to_id == 0
      abort "ERROR: FROM and TO are required. Usage: rake tx_base:merge_status FROM=old_id TO=new_id"
    end

    if from_id == to_id
      abort "ERROR: FROM and TO must be different."
    end

    from_status = IssueStatus.find_by(id: from_id)
    to_status   = IssueStatus.find_by(id: to_id)

    unless from_status
      abort "ERROR: IssueStatus with id=#{from_id} not found."
    end
    unless to_status
      abort "ERROR: IssueStatus with id=#{to_id} not found."
    end

    # original_name 지원 (tx_localization 패치 적용 시)
    from_name = from_status.respond_to?(:original_name) ? from_status.original_name : from_status.name
    to_name   = to_status.respond_to?(:original_name) ? to_status.original_name : to_status.name

    puts "=" * 60
    puts dry_run ? "[ DRY RUN ] No changes will be made." : "[ LIVE RUN ]"
    puts "=" * 60
    puts "Merge: #{from_name} (id=#{from_id}) → #{to_name} (id=#{to_id})"
    puts "-" * 60

    # --- 영향 범위 조사 ---
    counts = {}

    # 1. Issues
    counts[:issues] = Issue.where(status_id: from_id).count
    puts "Issues to update: #{counts[:issues]}"

    # 2. Journal details (status_id changes)
    jd_scope = JournalDetail.where(property: 'attr', prop_key: 'status_id')
    counts[:jd_old_value] = jd_scope.where(old_value: from_id.to_s).count
    counts[:jd_value]     = jd_scope.where(value: from_id.to_s).count
    puts "JournalDetail old_value refs: #{counts[:jd_old_value]}"
    puts "JournalDetail value refs: #{counts[:jd_value]}"

    # 3. No-op journal details (after merge, old_value == value)
    # Cases: (from→X where X=to), (X→from where X=to), (from→from)
    noop_count = jd_scope.where(
      "( old_value = :from AND value = :to ) OR " \
      "( old_value = :to AND value = :from ) OR " \
      "( old_value = :from AND value = :from )",
      from: from_id.to_s, to: to_id.to_s
    ).count
    counts[:noop_details] = noop_count
    puts "No-op JournalDetails to remove: #{counts[:noop_details]}"

    # 4. Workflows
    counts[:wf_old] = WorkflowTransition.where(old_status_id: from_id).count
    counts[:wf_new] = WorkflowTransition.where(new_status_id: from_id).count
    puts "WorkflowTransition old_status refs: #{counts[:wf_old]}"
    puts "WorkflowTransition new_status refs: #{counts[:wf_new]}"

    # 5. Queries (serialized filters)
    query_ids = []
    Query.where(type: 'IssueQuery').find_each do |q|
      next unless q.filters.is_a?(Hash)
      status_filter = q.filters['status_id']
      next unless status_filter.is_a?(Hash) && status_filter['values'].is_a?(Array)
      if status_filter['values'].include?(from_id.to_s)
        query_ids << q.id
      end
    end
    counts[:queries] = query_ids.size
    puts "Saved queries to update: #{counts[:queries]}"

    # 6. tx_localizations (conditional)
    has_tx_localizations = ActiveRecord::Base.connection.table_exists?('tx_localizations')
    if has_tx_localizations
      counts[:tx_loc] = TxLocalization.where(localizable_type: 'IssueStatus', localizable_id: from_id).count
      puts "TxLocalizations to remove: #{counts[:tx_loc]}"
    end

    puts "-" * 60

    if dry_run
      puts "[ DRY RUN ] Complete. Re-run without DRY_RUN=true to execute."
      next
    end

    # --- 실행 ---
    ActiveRecord::Base.transaction do
      # 1. Issues
      if counts[:issues] > 0
        Issue.where(status_id: from_id).update_all(status_id: to_id)
        puts "[OK] Issues updated: #{counts[:issues]}"
      end

      # 2. Journal details - update references
      jd_scope = JournalDetail.where(property: 'attr', prop_key: 'status_id')

      if counts[:jd_old_value] > 0
        jd_scope.where(old_value: from_id.to_s).update_all(old_value: to_id.to_s)
        puts "[OK] JournalDetail old_value updated: #{counts[:jd_old_value]}"
      end

      if counts[:jd_value] > 0
        jd_scope.where(value: from_id.to_s).update_all(value: to_id.to_s)
        puts "[OK] JournalDetail value updated: #{counts[:jd_value]}"
      end

      # 3. Remove no-op journal details (old_value == value after merge)
      if counts[:noop_details] > 0
        noop_ids = jd_scope.where("old_value = value").pluck(:id)
        # 이 journal_detail 들이 속한 journal 의 id 를 미리 수집
        orphan_journal_ids = jd_scope.where(id: noop_ids).pluck(:journal_id).uniq

        JournalDetail.where(id: noop_ids).delete_all
        puts "[OK] No-op JournalDetails removed: #{noop_ids.size}"

        # 빈 journal 정리 (detail 도 없고 notes 도 없는 경우)
        empty_journal_count = 0
        Journal.where(id: orphan_journal_ids).find_each do |journal|
          next if journal.details.any?
          next if journal.notes.present?
          journal.destroy
          empty_journal_count += 1
        end
        puts "[OK] Empty journals removed: #{empty_journal_count}" if empty_journal_count > 0
      end

      # 4. Workflows - merge transitions
      # old_status_id 변환
      WorkflowTransition.where(old_status_id: from_id).find_each do |wf|
        existing = WorkflowTransition.find_by(
          tracker_id: wf.tracker_id, role_id: wf.role_id,
          old_status_id: to_id, new_status_id: wf.new_status_id,
          type: wf.type
        )
        if existing
          wf.destroy
        else
          wf.update_columns(old_status_id: to_id)
        end
      end
      puts "[OK] WorkflowTransition old_status merged" if counts[:wf_old] > 0

      # new_status_id 변환
      WorkflowTransition.where(new_status_id: from_id).find_each do |wf|
        existing = WorkflowTransition.find_by(
          tracker_id: wf.tracker_id, role_id: wf.role_id,
          old_status_id: wf.old_status_id, new_status_id: to_id,
          type: wf.type
        )
        if existing
          wf.destroy
        else
          wf.update_columns(new_status_id: to_id)
        end
      end
      puts "[OK] WorkflowTransition new_status merged" if counts[:wf_new] > 0

      # self-transition 정리 (old_status == new_status 이면서 의미 없는 것)
      WorkflowTransition.where(old_status_id: to_id, new_status_id: to_id).destroy_all

      # 5. Queries
      if counts[:queries] > 0
        Query.where(id: query_ids).find_each do |q|
          values = q.filters['status_id']['values']
          values.map! { |v| v == from_id.to_s ? to_id.to_s : v }
          values.uniq!
          q.save!
        end
        puts "[OK] Saved queries updated: #{counts[:queries]}"
      end

      # 6. tx_localizations
      if has_tx_localizations && counts[:tx_loc] > 0
        TxLocalization.where(localizable_type: 'IssueStatus', localizable_id: from_id).destroy_all
        puts "[OK] TxLocalizations removed: #{counts[:tx_loc]}"
      end

      # 7. Delete the old status
      from_status.destroy!
      puts "[OK] IssueStatus '#{from_name}' (id=#{from_id}) deleted."

      puts "=" * 60
      puts "Merge complete: #{from_name} (id=#{from_id}) → #{to_name} (id=#{to_id})"
      puts "=" * 60
    end
  end
end
