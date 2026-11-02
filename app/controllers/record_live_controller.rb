class RecordLiveController < ApplicationController
  def show
    response.headers['Cache-Control'] = 'private, no-store'
    @record = Record.find(params[:record_id])
    @record_live_version = RecordShowVersion.new(@record).call
    return head :no_content if params[:version] == @record_live_version

    @record.reload
    html = render_to_string(template: 'records/show', formats: [:html], layout: false)
    return head :conflict unless RecordShowVersion.new(@record.reload).call == @record_live_version

    render json: { version: @record_live_version, html: html }
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end
end
