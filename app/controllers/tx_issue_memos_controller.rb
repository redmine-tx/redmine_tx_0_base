class TxIssueMemosController < ApplicationController
  before_action :require_login
  before_action :find_issue, only: [:edit, :update]
  before_action :authorize_issue_edit, only: [:edit, :update]
  before_action :find_memo_custom_field, only: [:edit, :update]

  def index
    render json: { issue_memos: TxBaseHelper.issue_memos_for(requested_issue_ids, User.current) }
  end

  def edit
    respond_to do |format|
      format.html { redirect_to issue_path(@issue) }
      format.js
    end
  end

  def update
    if @issue.update_memo!(memo_value, user: User.current)
      flash.now[:notice] = l(:notice_tx_issue_memo_updated)
      respond_to do |format|
        format.html { redirect_to issue_path(@issue), notice: l(:notice_tx_issue_memo_updated) }
        format.js
      end
    else
      respond_to do |format|
        format.html { redirect_to issue_path(@issue), alert: @issue.errors.full_messages.to_sentence }
        format.js { render :update, status: :unprocessable_entity }
      end
    end
  end

  private

  def find_issue
    @issue = Issue.visible.find(params[:issue_id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def authorize_issue_edit
    render_403 unless @issue.attributes_editable?(User.current)
  end

  def find_memo_custom_field
    @memo_custom_field = @issue.memo_custom_field
    render_404 unless @memo_custom_field && @issue.memo_editable?(User.current)
  end

  def memo_value
    params.dig(:tx_issue_memo, :value).to_s
  end

  def requested_issue_ids
    Array(params[:ids] || params[:issue_ids]).each_with_object([]) do |value, ids|
      value.to_s.split(',').each do |token|
        ids << token.to_i if token.match?(/\A\d+\z/)
      end
    end.select(&:positive?).uniq.take(200)
  end
end
