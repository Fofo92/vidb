class TvRecordingIntentScheduleTitlesController < ApplicationController
  ERRORS = [
    Tv::GuideScheduleTitleChooser::Unavailable,
    Tv::RecordingIntentScheduleRenamer::Unavailable,
    Tv::RecordingIntentScheduleAttributes::Unavailable,
    Tv::KaffeineScheduleMatcher::AmbiguousMatch,
    Tv::KaffeineScheduleManager::Error,
    Tv::KaffeineCommandRunner::CommandError,
    Tv::KaffeineScheduleParser::InvalidResponse,
    Tv::KaffeineScheduleLock::Busy,
    ActiveRecord::RecordInvalid
  ].freeze

  def create
    intent = Tv::RecordingIntent.find(params[:tv_recording_intent_id])
    observation = Tv::BroadcastObservation.find(params.require(:broadcast_observation_id))
    schedule = Tv::GuideScheduleTitleChooser.new(
      recording_intent: intent, observation:, client: Tv::KaffeineDbus.new
    ).call
    redirect_to tv_guide_path(guide_params), notice: "Titre Kaffeine confirmé (n° #{schedule.key})."
  rescue *ERRORS => e
    Rails.logger.warn("Kaffeine title update rejected: #{e.class}: #{e.message}")
    redirect_to tv_guide_path(guide_params), alert: "Titre non confirmé : vérifiez la programmation Kaffeine."
  end

  private

  def guide_params
    params.permit(:date, :guide_source_id, :zoom, :all_channels)
  end
end
