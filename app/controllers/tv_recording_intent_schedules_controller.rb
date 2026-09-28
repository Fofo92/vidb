class TvRecordingIntentSchedulesController < ApplicationController
  SCHEDULING_ERRORS = [
    Tv::RecordingIntentScheduleAttributes::Unavailable,
    Tv::KaffeineScheduleMatcher::AmbiguousMatch,
    Tv::RecordingIntentScheduler::LinkedScheduleMismatch,
    Tv::KaffeineScheduleManager::Error,
    Tv::KaffeineCommandRunner::CommandError,
    Tv::KaffeineScheduleParser::InvalidResponse,
    Tv::KaffeineScheduleLock::Busy,
    ActiveRecord::RecordInvalid
  ].freeze

  def create
    intent = Tv::RecordingIntent.find(params[:tv_recording_intent_id])
    schedule = schedule_intent(intent)
    redirect_to(return_path, notice: "Programmation Kaffeine confirmée (n° #{schedule.key}).")
  rescue *SCHEDULING_ERRORS
    redirect_to(
      return_path,
      alert: "Programmation non confirmée : vérifiez Kaffeine avant de recommencer."
    )
  end

  private

  def return_path
    return tv_guide_path(guide_params) if params[:return_to] == "guide"

    tv_recording_intents_path
  end

  def guide_params
    params.permit(:date, :guide_source_id, :zoom, :all_channels)
  end

  def schedule_intent(intent)
    client = Tv::KaffeineDbus.new
    Tv::RecordingIntentScheduler.new(recording_intent: intent, client:).call
  end
end
