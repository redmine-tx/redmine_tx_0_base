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

    begin
      merger = TxBaseHelper::StatusMerger.new(from_id, to_id)
    rescue ArgumentError => e
      abort "ERROR: #{e.message}"
    rescue ActiveRecord::RecordNotFound => e
      abort "ERROR: #{e.message}"
    end

    puts "=" * 60
    puts dry_run ? "[ DRY RUN ] No changes will be made." : "[ LIVE RUN ]"
    puts "=" * 60
    puts "Merge: #{merger.from_name} (id=#{from_id}) → #{merger.to_name} (id=#{to_id})"
    puts "-" * 60

    counts = merger.preview

    # is_closed 불일치 경고
    if counts[:is_closed_mismatch]
      puts "WARNING: is_closed mismatch! FROM=#{merger.from_status.is_closed}, TO=#{merger.to_status.is_closed}"
      if merger.from_status.is_closed? && !merger.to_status.is_closed?
        puts "  → Issues will move from CLOSED to OPEN status. closed_on will be cleared."
      else
        puts "  → Issues will move from OPEN to CLOSED status. closed_on will be set."
      end
    end

    puts "Issues to update: #{counts[:issues]}"
    puts "JournalDetail old_value refs: #{counts[:jd_old_value]}"
    puts "JournalDetail value refs: #{counts[:jd_value]}"
    puts "No-op JournalDetails to remove: #{counts[:noop_details]}"
    puts "WorkflowTransition old_status refs: #{counts[:wf_old]}"
    puts "WorkflowTransition new_status refs: #{counts[:wf_new]}"
    puts "WorkflowPermission old_status refs: #{counts[:wp_old]}"
    puts "WorkflowPermission new_status refs: #{counts[:wp_new]}"
    puts "Trackers default_status to update: #{counts[:trackers]}"
    puts "Saved queries to update: #{counts[:queries]}"
    puts "Commit update keyword rules to update: #{counts[:commit_keywords]}" if counts[:commit_keywords] > 0
    puts "TxLocalizations to remove: #{counts[:tx_loc]}" if counts[:tx_loc].to_i > 0
    puts "-" * 60

    if dry_run
      puts "[ DRY RUN ] Complete. Re-run without DRY_RUN=true to execute."
      next
    end

    merger.execute!

    puts "=" * 60
    puts "Merge complete: #{merger.from_name} (id=#{from_id}) → #{merger.to_name} (id=#{to_id})"
    puts "=" * 60
  end
end
