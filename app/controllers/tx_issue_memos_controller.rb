class TxIssueMemosController < ApplicationController
  before_action :require_login
  before_action :find_issue
  before_action :authorize_issue_edit
  before_action :find_memo_custom_field

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
end
