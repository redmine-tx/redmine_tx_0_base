RedmineApp::Application.routes.draw do
  # 최상위 부모 일감 자동완성 (공용 API)
  get 'tx_base/top_parent_issues', to: 'tx_base_autocompletes#top_parent_issues', as: 'tx_base_top_parent_issues'

  # 일감 빠른 메모
  get   'tx_issue_memos', to: 'tx_issue_memos#index', as: 'tx_issue_memos'
  get   'issues/:issue_id/tx_issue_memo/edit', to: 'tx_issue_memos#edit', as: 'edit_tx_issue_memo'
  match 'issues/:issue_id/tx_issue_memo', to: 'tx_issue_memos#update', via: [:patch, :put], as: 'tx_issue_memo'

  # 일감 상태 병합
  get  'issue_statuses/:id/merge', to: 'tx_status_merge#show', as: 'tx_status_merge'
  get  'issue_statuses/:id/merge/preview', to: 'tx_status_merge#preview', as: 'preview_tx_status_merge'
  post 'issue_statuses/:id/merge', to: 'tx_status_merge#create'
end
