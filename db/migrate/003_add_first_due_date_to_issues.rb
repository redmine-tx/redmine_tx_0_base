class AddFirstDueDateToIssues < ActiveRecord::Migration[5.2]
  class MigrationIssue < ActiveRecord::Base
    self.table_name = 'issues'
  end

  class MigrationJournalDetail < ActiveRecord::Base
    self.table_name = 'journal_details'
  end

  class MigrationVersion < ActiveRecord::Base
    self.table_name = 'versions'
  end

  def up
    unless column_exists?(:issues, :first_due_date)
      add_column :issues, :first_due_date, :date
      add_index :issues, :first_due_date unless index_exists?(:issues, :first_due_date)
    end

    MigrationIssue.reset_column_information
    backfill_first_due_date
  end

  def down
    remove_index :issues, :first_due_date if index_exists?(:issues, :first_due_date)
    remove_column :issues, :first_due_date if column_exists?(:issues, :first_due_date)
  end

  private

  def backfill_first_due_date
    scope = MigrationIssue.where(first_due_date: nil)
    return unless scope.exists?

    say_with_time 'Backfilling issues.first_due_date' do
      scope.find_in_batches(batch_size: 500) do |issues|
        tracking_rows = MigrationJournalDetail
          .joins('INNER JOIN journals ON journals.id = journal_details.journal_id')
          .where(journals: { journalized_type: 'Issue', journalized_id: issues.map(&:id) })
          .where(property: 'attr', prop_key: %w[due_date fixed_version_id])
          .select(
            'journals.journalized_id AS issue_id',
            'journals.id AS journal_id',
            'journals.created_on AS journal_created_on',
            'journal_details.prop_key',
            'journal_details.old_value',
            'journal_details.value'
          )
          .order('journals.journalized_id ASC, journals.created_on ASC, journals.id ASC, journal_details.id ASC')
          .to_a
        history_by_issue_id = build_history_by_issue_id(tracking_rows)

        issues.each do |issue|
          first_due_date = baseline_due_date_for_issue(issue, history_by_issue_id[issue.id] || [])
          next unless first_due_date.present?

          MigrationIssue.where(id: issue.id).update_all(first_due_date: first_due_date)
        end
      end
    end
  end

  def parse_date(value)
    return nil if value.blank?
    return value.to_date if value.respond_to?(:to_date)

    Date.parse(value.to_s)
  rescue ArgumentError, TypeError
    nil
  end

  def build_history_by_issue_id(tracking_rows)
    tracking_rows.each_with_object({}) do |row, history_by_issue_id|
      issue_id = row.issue_id.to_i
      history_by_issue_id[issue_id] ||= []

      current_entry = history_by_issue_id[issue_id].last
      if current_entry.nil? || current_entry[:journal_id] != row.journal_id.to_i
        current_entry = {
          journal_id: row.journal_id.to_i,
          created_on: row.journal_created_on,
          due_date_detail: nil,
          fixed_version_detail: nil
        }
        history_by_issue_id[issue_id] << current_entry
      end

      detail_data = { old_value: row.old_value, value: row.value }
      if row.prop_key == 'due_date'
        current_entry[:due_date_detail] = detail_data
      elsif row.prop_key == 'fixed_version_id'
        current_entry[:fixed_version_detail] = detail_data
      end
    end
  end

  def baseline_due_date_for_issue(issue, history)
    current_due_date = initial_due_date_from_history(issue, history)
    current_fixed_version_id = initial_fixed_version_id_from_history(issue, history)
    baseline_due_date = current_due_date

    history.each do |entry|
      due_date_detail = entry[:due_date_detail]
      fixed_version_detail = entry[:fixed_version_detail]
      next unless due_date_detail || fixed_version_detail

      new_due_date = due_date_detail ? parse_date(due_date_detail[:value]) : current_due_date
      new_fixed_version_id = fixed_version_detail ? parse_version_id(fixed_version_detail[:value]) : current_fixed_version_id

      if fixed_version_detail && version_delay_reset?(current_fixed_version_id, new_fixed_version_id)
        baseline_due_date = new_due_date
      elsif baseline_due_date.nil? && due_date_detail && new_due_date.present?
        baseline_due_date = new_due_date
      end

      current_due_date = new_due_date if due_date_detail
      current_fixed_version_id = new_fixed_version_id if fixed_version_detail
    end

    baseline_due_date
  end

  def initial_due_date_from_history(issue, history)
    first_due_date_entry = history.find { |entry| entry[:due_date_detail].present? }
    return issue.due_date if first_due_date_entry.nil?

    parse_date(first_due_date_entry[:due_date_detail][:old_value])
  end

  def initial_fixed_version_id_from_history(issue, history)
    first_fixed_version_entry = history.find { |entry| entry[:fixed_version_detail].present? }
    return parse_version_id(issue.fixed_version_id) if first_fixed_version_entry.nil?

    parse_version_id(first_fixed_version_entry[:fixed_version_detail][:old_value])
  end

  def parse_version_id(value)
    return nil if value.blank?

    normalized_id = value.to_i
    normalized_id.positive? ? normalized_id : nil
  end

  def version_delay_reset?(old_version_id, new_version_id)
    old_effective_date = version_effective_date(old_version_id)
    new_effective_date = version_effective_date(new_version_id)

    old_effective_date.present? &&
      new_effective_date.present? &&
      new_effective_date > old_effective_date
  end

  def version_effective_date(version_id)
    normalized_id = parse_version_id(version_id)
    return nil unless normalized_id

    @version_effective_date_cache ||= {}
    return @version_effective_date_cache[normalized_id] if @version_effective_date_cache.key?(normalized_id)

    @version_effective_date_cache[normalized_id] =
      MigrationVersion.where(id: normalized_id).pick(:effective_date)
  end
end
