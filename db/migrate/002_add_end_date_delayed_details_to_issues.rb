class AddEndDateDelayedDetailsToIssues < ActiveRecord::Migration[5.2]
  def up
    # 연기 시점의 담당자 ID
    unless column_exists?(:issues, :end_date_delayed_by_id)
      add_column :issues, :end_date_delayed_by_id, :integer
      add_index :issues, :end_date_delayed_by_id unless index_exists?(:issues, :end_date_delayed_by_id)
    end

    # 영업일 기준 연기 일수 (주말/공휴일 제외)
    unless column_exists?(:issues, :end_date_delayed_days)
      add_column :issues, :end_date_delayed_days, :integer
      add_index :issues, :end_date_delayed_days unless index_exists?(:issues, :end_date_delayed_days)
    end
  end

  def down
    remove_index :issues, :end_date_delayed_by_id if index_exists?(:issues, :end_date_delayed_by_id)
    remove_column :issues, :end_date_delayed_by_id if column_exists?(:issues, :end_date_delayed_by_id)

    remove_index :issues, :end_date_delayed_days if index_exists?(:issues, :end_date_delayed_days)
    remove_column :issues, :end_date_delayed_days if column_exists?(:issues, :end_date_delayed_days)
  end
end
