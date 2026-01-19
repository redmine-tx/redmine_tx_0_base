class TxBaseAutocompletesController < ApplicationController
  before_action :find_project

  # 최상위 부모 일감만 대상으로 자동완성 검색
  def top_parent_issues
    issues = []
    q = (params[:q] || params[:term]).to_s.strip
    status = params[:status].to_s
    issue_id = params[:issue_id].to_s

    roadmap_tracker_ids = Tracker.roadmap_trackers_ids.presence || [0]
    excluded_tracker_ids = (Tracker.bug_trackers_ids +
                            Tracker.exception_trackers_ids).uniq
    status_priority_ids = (IssueStatus.new_ids + IssueStatus.in_progress_ids + IssueStatus.in_review_ids).uniq

    scope = Issue.cross_project_scope(@project, params[:scope]).visible.where(parent_id: nil)
    scope = scope.where.not(tracker_id: excluded_tracker_ids) if excluded_tracker_ids.any?
    scope = scope.open(status == 'o') if status.present?
    scope = scope.where.not(id: issue_id.to_i) if issue_id.present?
    priority_order_sql = "CASE WHEN issues.status_id IN (#{status_priority_ids.join(',')}) THEN 0 ELSE 1 END ASC, CASE WHEN issues.tracker_id IN (#{roadmap_tracker_ids.join(',')}) THEN 0 ELSE 1 END ASC, issues.id DESC"

    if q.present?
      if q =~ /\A#?(\d+)\z/
        issues << scope.order(Arel.sql(priority_order_sql))
                       .find_by(id: Regexp.last_match(1).to_i)
      end
      issues += scope.like(q)
                    .order(Arel.sql(priority_order_sql))
                    .limit(10).to_a
      issues.compact!
      issues = issues.uniq { |i| i.id }
      issues.sort_by! do |i|
        [
          status_priority_ids.include?(i.status_id) ? 0 : 1,
          roadmap_tracker_ids.include?(i.tracker_id) ? 0 : 1,
          -i.id
        ]
      end
    else
      issues += scope.order(Arel.sql(priority_order_sql)).limit(10).to_a
    end

    render json: format_issues_json(issues)
  end

  private

  def find_project
    @project = Project.find(params[:project_id]) if params[:project_id].present?
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def format_issues_json(issues)
    issues.map do |issue|
      {
        'id' => issue.id,
        'label' => "#{issue.tracker} ##{issue.id}: #{issue.subject.to_s.truncate(255)}",
        'value' => issue.id
      }
    end
  end
end
