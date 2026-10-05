class RecordStatesController < ApplicationController
  def update
    @record = Record.find(params[:record_id])
    count = RecordStateUpdate.new(parent: @record, **state_params.to_h.symbolize_keys).call
    @record.reload
    render json: response_payload(count)
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_content
  end

  private

  def state_params
    params.require(:state).permit(:field, :value, :child_id)
  end

  def response_payload(count)
    {
      count: count,
      summary: state_fragment("state_summary"),
      rows: state_fragment("child_rows")
    }
  end

  def state_fragment(name)
    render_to_string(partial: "records/#{name}", formats: [:html], locals: { record: @record })
  end
end
