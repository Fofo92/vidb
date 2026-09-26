class TvRecordingIntentsController < ApplicationController
  def create
    observation = Tv::BroadcastObservation.find(
      params.require(:broadcast_observation_id)
    )

    Tv::RecordingIntentSelector.new(
      broadcast_observation: observation
    ).call

    redirect_to(
      tv_guide_path(guide_params),
      notice: "Le programme a été sélectionné pour enregistrement."
    )
  end

  def destroy
    intent = Tv::RecordingIntent.find(params[:id])

    Tv::RecordingIntentCanceller.new(
      recording_intent: intent
    ).call

    redirect_to(
      tv_guide_path(guide_params),
      notice: "La sélection pour enregistrement a été annulée."
    )
  end

  private

  def guide_params
    params.permit(
      :date,
      :guide_source_id,
      :zoom,
      :all_channels
    )
  end
end
