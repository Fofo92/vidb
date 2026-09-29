class TvRecordingIntentSchedulesController < ApplicationController
  SCHEDULING_ERRORS = Tv::RecordingIntentScheduler::ERRORS

  def create
    intent = Tv::RecordingIntent.find(params[:tv_recording_intent_id])
    schedule = schedule_intent(intent)
    redirect_to(return_path, notice: "Programmation Kaffeine confirmée (n° #{schedule.key}).")
  rescue Tv::MultiplexCapacityGuard::Warning => e
    redirect_to(return_path, alert: "Programmation suspendue : #{e.message}")
  rescue Tv::RecordingIntentScheduler::ScheduledEpisodeDuplicate => e
    redirect_to_duplicate_warning(e)
  rescue *SCHEDULING_ERRORS
    redirect_to_failed_schedule
  end

  private

  def redirect_to_duplicate_warning(error)
    redirect_to(return_path, alert: error.message)
  end

  def redirect_to_failed_schedule
    redirect_to(return_path, alert: "Programmation non confirmée : vérifiez Kaffeine avant de recommencer.")
  end

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
