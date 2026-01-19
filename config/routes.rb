RedmineApp::Application.routes.draw do
  # 최상위 부모 일감 자동완성 (공용 API)
  get 'tx_base/top_parent_issues', to: 'tx_base_autocompletes#top_parent_issues', as: 'tx_base_top_parent_issues'
end
