Redmine::Plugin.register :redmine_tx_0_base do
  name 'Redmine Tx Base plugin'
  author 'KiHyun Kang'
  description 'This is a plugin for Redmine'
  version '0.0.2'
  url 'http://example.com/path/to/plugin'
  author_url 'testors@gmail.com'

  settings default: {
    'empty' => true,
    'show_top_projects' => '1',  # 상단 메뉴바 프로젝트 바로가기 (기본: 켜짐)
    'project_context_menu' => ''  # 프로젝트 컨텍스트 메뉴 항목
  }, partial: 'settings/tx_base'

  menu :top_menu, :issues, 
  { controller: 'issues', action: 'index' }, 
  caption: '일감',
  if: Proc.new { User.current.logged? }
end

Rails.application.config.after_initialize do
  require_dependency File.expand_path('../lib/tx_base_helper', __FILE__)
  require_dependency File.expand_path('../lib/tx_base_hook', __FILE__)
  require_dependency File.expand_path('../lib/tx_base_helper/issue_query_column_helper', __FILE__)
  require_dependency File.expand_path('../lib/tx_base_helper/issue_query_dsl', __FILE__)
  require_dependency File.expand_path('../lib/tx_base_helper/holiday_api', __FILE__)
  require_dependency File.expand_path('../lib/tx_base_helper/user_vacation_api', __FILE__)

  TxBaseHelper.register_issue_query_columns do
    column :end_date_changed_on, filter: :date_past
    column :end_date_delayed_on, filter: :date_past
    user_column :end_date_delayed_by  # 연기 시점의 담당자
    column :end_date_delayed_days, filter: { type: :integer }  # 연기 일수 (영업일 기준)

    virtual_column :fixed_version_plus,
      value: ->(issue) { issue.fixed_version_plus },
      caption: :field_fixed_version_plus,
      sortable: "#{Version.table_name}.effective_date"

    virtual_column :estimated_hours_plus,
      value: ->(issue) { issue.estimated_hours_plus },
      caption: :field_estimated_hours_plus,
      sortable: "estimated_hours"
  end
  
  # 플러그인 설정 변경 시 캐시 클리어
  Setting.class_eval do
    after_save :clear_tx_base_cache_if_needed
    
    def clear_tx_base_cache_if_needed
      if self.name == 'plugin_redmine_tx_0_base'
        Rails.cache.delete(TxBaseHook::PROJECTS_CACHE_KEY)
        Rails.logger.info "TxBase: Cleared top projects cache due to settings change"
      end
    end
  end
end
