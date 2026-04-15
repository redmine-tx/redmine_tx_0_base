require File.expand_path('../../test_helper', __FILE__)

class TxIssueMemosControllerTest < Redmine::ControllerTest
  fixtures :projects,
           :trackers,
           :projects_trackers,
           :roles,
           :member_roles,
           :members,
           :enabled_modules,
           :workflows,
           :journals,
           :journal_details,
           :versions,
           :issues,
           :issue_statuses,
           :issue_categories,
           :users,
           :enumerations,
           :custom_fields,
           :custom_values,
           :custom_fields_trackers,
           :custom_fields_projects

  def setup
    @request.session[:user_id] = 2
    @issue = Issue.find(1)
  end

  def test_should_open_edit_modal_with_current_memo
    with_issue_memo_setting do
      compatible_xhr_request :get, :edit, issue_id: @issue.id

      assert_response :success
      assert_match 'text/javascript', response.content_type
      assert_includes response.body, 'tx_issue_memo_value'
      assert_includes response.body, '125'
    end
  end

  def test_should_update_issue_memo_custom_field
    with_issue_memo_setting do
      assert_difference -> { @issue.reload.journals.count }, 1 do
        compatible_xhr_request :patch, :update,
                               issue_id: @issue.id,
                               tx_issue_memo: { value: 'Updated memo' }
      end

      assert_response :success
      assert_equal 'Updated memo', @issue.reload.memo
      assert_match 'text/javascript', response.content_type
    end
  end

  def test_should_return_missing_when_memo_field_is_not_configured
    with_settings plugin_redmine_tx_0_base: Setting[:plugin_redmine_tx_0_base].merge('issue_memo_custom_field_id' => '') do
      compatible_xhr_request :get, :edit, issue_id: @issue.id
      assert_response :missing
    end
  end

  private

  def with_issue_memo_setting(&block)
    with_settings plugin_redmine_tx_0_base: Setting[:plugin_redmine_tx_0_base].merge('issue_memo_custom_field_id' => '2'), &block
  end
end
