class AddEndDateDelayedDetailsToIssues < ActiveRecord::Migration[5.2]
  def change
    # 연기 시점의 담당자 ID
    add_column :issues, :end_date_delayed_by_id, :integer
    add_index :issues, :end_date_delayed_by_id

    # 영업일 기준 연기 일수 (주말/공휴일 제외)
    add_column :issues, :end_date_delayed_days, :integer
    add_index :issues, :end_date_delayed_days
  end
end
