require File.expand_path('../test_helper', __dir__)

class TxBaseIssueQueryDslTest < ActiveSupport::TestCase
  fixtures :projects,
           :users,
           :roles,
           :members,
           :member_roles,
           :trackers,
           :projects_trackers,
           :issue_statuses,
           :issues,
           :enumerations

  def setup
    @previous_user = User.current
    User.current = User.find(2)
  end

  def teardown
    User.current = @previous_user
  end

  def test_filter_values_proc_runs_in_issue_query_context
    filter_name = 'tx_dsl_context_values'

    TxBaseHelper.register_issue_query_columns do
      filter filter_name,
             type: :list,
             values: -> { [[project.identifier, project.id.to_s]] }
    end

    project = Project.find(1)
    query = IssueQuery.new(project: project)
    filter = query.available_filters[filter_name]

    assert filter.remote
    assert_equal [[project.identifier, project.id.to_s]], filter.values
  end
end
