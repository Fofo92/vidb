class RecordRatingsController < ApplicationController
  def update
    @record = Record.find(params[:record_id])
    RecordRatingUpdate.call(record: @record, user: current_user, value: rating_value)
    return redirect_to record_path(@record), status: :see_other unless turbo_frame_request?

    render_rating
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    @record.reload
    render_rating(error: e.message, status: :unprocessable_content)
  end

  private

  def rating_value
    value = params.require(:rating).fetch(:value)
    return nil if value.nil? || value == ''

    raise ArgumentError, 'Choisis une note de 1 à 5 étoiles.' unless value.to_s.match?(/\A[1-5]\z/)

    value.to_i
  end

  def render_rating(error: nil, status: :ok)
    render partial: 'records/rating', formats: [:html], locals: { record: @record, error: error }, status: status
  end
end
