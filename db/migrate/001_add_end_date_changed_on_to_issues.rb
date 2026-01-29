class AddEndDateChangedOnToIssues < ActiveRecord::Migration[5.2]
  def up
    unless column_exists?(:issues, :end_date_changed_on)
      add_column :issues, :end_date_changed_on, :datetime
      add_index :issues, :end_date_changed_on unless index_exists?(:issues, :end_date_changed_on)
    end

    unless column_exists?(:issues, :end_date_delayed_on)
      add_column :issues, :end_date_delayed_on, :datetime
      add_index :issues, :end_date_delayed_on unless index_exists?(:issues, :end_date_delayed_on)
    end
  end

  def down
    remove_index :issues, :end_date_changed_on if index_exists?(:issues, :end_date_changed_on)
    remove_column :issues, :end_date_changed_on if column_exists?(:issues, :end_date_changed_on)

    remove_index :issues, :end_date_delayed_on if index_exists?(:issues, :end_date_delayed_on)
    remove_column :issues, :end_date_delayed_on if column_exists?(:issues, :end_date_delayed_on)
  end
end
