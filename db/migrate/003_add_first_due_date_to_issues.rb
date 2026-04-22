class AddFirstDueDateToIssues < ActiveRecord::Migration[5.2]
  class MigrationIssue < ActiveRecord::Base
    self.table_name = 'issues'
  end

  class MigrationJournalDetail < ActiveRecord::Base
    self.table_name = 'journal_details'
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
        issue_ids = issues.map(&:id)
        first_due_dates = {}

        MigrationJournalDetail
          .joins('INNER JOIN journals ON journals.id = journal_details.journal_id')
          .where(journals: { journalized_type: 'Issue', journalized_id: issue_ids })
          .where(property: 'attr', prop_key: 'due_date')
          .select(
            'journals.journalized_id AS issue_id',
            'journals.created_on AS journal_created_on',
            'journal_details.id AS detail_id',
            'journal_details.old_value',
            'journal_details.value'
          )
          .order('journals.journalized_id ASC, journals.created_on ASC, journal_details.id ASC')
          .each do |detail|
            issue_id = detail.issue_id.to_i
            next if first_due_dates.key?(issue_id)

            first_due_date = parse_date(detail.old_value) || parse_date(detail.value)
            first_due_dates[issue_id] = first_due_date if first_due_date.present?
          end

        issues.each do |issue|
          first_due_date = first_due_dates[issue.id] || issue.due_date
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
end
