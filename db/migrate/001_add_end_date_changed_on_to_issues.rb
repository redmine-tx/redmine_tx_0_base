class AddEndDateChangedOnToIssues < ActiveRecord::Migration[5.2]
  def change
    add_column :issues, :end_date_changed_on, :datetime
    add_index :issues, :end_date_changed_on

    add_column :issues, :end_date_delayed_on, :datetime
    add_index :issues, :end_date_delayed_on
  end
end
