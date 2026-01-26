Redmine::Plugin.register :redmine_tx_0_base do
  name 'Redmine Tx Base plugin'
  author 'KiHyun Kang'
  description 'This is a plugin for Redmine'
  version '0.0.2'
  url 'http://example.com/path/to/plugin'
  author_url 'testors@gmail.com'

  settings default: {'empty' => true}, partial: 'settings/tx_base'

  menu :top_menu, :issues, 
  { controller: 'issues', action: 'index' }, 
  caption: '일감',
  if: Proc.new { User.current.logged? }
end

Rails.application.config.after_initialize do
  require_dependency File.expand_path('../lib/tx_base_helper', __FILE__)
  require_dependency File.expand_path('../lib/tx_base_hook', __FILE__)
  require_dependency File.expand_path('../lib/tx_base_helper/issue_query_column_helper', __FILE__)
  require_dependency File.expand_path('../lib/tx_base_helper/patches/issue_query_patch', __FILE__)
end
