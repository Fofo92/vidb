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
    redirect_to(tv_recording_intents_path, notice: "Programmation Kaffeine confirmée (n° #{schedule.key}).")
  rescue *SCHEDULING_ERRORS
    redirect_to(
      tv_recording_intents_path,
      alert: "Programmation non confirmée : vérifiez Kaffeine avant de recommencer."
    )
  end

  private

  def schedule_intent(intent)
    client = Tv::KaffeineDbus.new
    Tv::RecordingIntentScheduler.new(recording_intent: intent, client:).call
  end
end
