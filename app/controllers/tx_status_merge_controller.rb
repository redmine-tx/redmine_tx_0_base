class TxStatusMergeController < ApplicationController
  layout 'admin'
  before_action :require_admin
  before_action :find_status

  def show
    @statuses = IssueStatus.sorted.where.not(id: @status.id)
  end

  def preview
    to_id = params[:to_id].to_i
    if to_id == 0
      render json: { error: 'invalid' }, status: :bad_request
      return
    end

    begin
      merger = TxBaseHelper::StatusMerger.new(@status.id, to_id)
      counts = merger.preview
      render json: counts
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'not_found' }, status: :not_found
    end
  end

  def create
    to_id = params[:to_id].to_i
    if to_id == 0
      flash[:error] = l(:error_merge_target_required)
      redirect_to tx_status_merge_path(@status)
      return
    end

    begin
      merger = TxBaseHelper::StatusMerger.new(@status.id, to_id)
      merger.execute!
      flash[:notice] = l(:notice_status_merged, from: merger.from_name, to: merger.to_name)
      redirect_to issue_statuses_path
    rescue ActiveRecord::RecordNotFound
      flash[:error] = l(:error_status_not_found)
      redirect_to issue_statuses_path
    rescue => e
      flash[:error] = l(:error_merge_failed, message: e.message)
      redirect_to tx_status_merge_path(@status)
    end
  end

  private

  def find_status
    @status = IssueStatus.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end
end
