class TvRecordingIntentsController < ApplicationController
  SCHEDULING_ERRORS = Tv::RecordingIntentScheduler::ERRORS

  def index
    @filters = params.permit(:q, :date, :channel, :state, :history)
    table = Tv::RecordingScheduleTable.new(intents: selected_recording_intents, filters: @filters,
                                           title: helpers.method(:recording_intent_title))
    @rows = table.call
    @kaffeine_unavailable = table.unavailable
  end

  def create
    redirect_to_selected_intent(select_and_schedule)
  rescue Tv::RecordingIntentScheduler::ProgrammeEnded => e
    redirect_to tv_guide_path(guide_params), alert: e.message
  rescue Tv::MultiplexCapacityGuard::Warning => e
    redirect_to_capacity_warning(e)
  rescue Tv::RecordingIntentScheduler::ScheduledEpisodeDuplicate => e
    redirect_to_duplicate_warning(e)
  rescue *SCHEDULING_ERRORS => e
    redirect_to_unscheduled_intent(e)
  end

  def destroy
    intent = Tv::RecordingIntent.find(params[:id])
    cancel_intent(intent)
    redirect_to_cancelled_intent
  rescue Tv::RecordingIntentScheduleCanceller::LinkedScheduleMismatch,
         Tv::RecordingIntentScheduleCanceller::TooLateToCancel,
         Tv::KaffeineScheduleManager::VerificationError,
         Tv::KaffeineCommandRunner::CommandError,
         Tv::KaffeineScheduleParser::InvalidResponse,
         Tv::KaffeineScheduleLock::Busy => e
    redirect_to_blocked_cancellation(e)
  end

  private

  def select_and_schedule
    observation = Tv::BroadcastObservation.find(params.require(:broadcast_observation_id))
    raise Tv::RecordingIntentScheduler::ProgrammeEnded, "Ce programme est terminé." if observation.ended?

    intent = Tv::RecordingIntentSelector.new(broadcast_observation: observation).call
    schedule_selected_intent(intent)
  end

  def redirect_to_duplicate_warning(error)
    redirect_to tv_guide_path(guide_params), alert: "#{error.message} Le programme reste sélectionné."
  end

  def redirect_to_capacity_warning(error)
    redirect_to tv_guide_path(guide_params),
                alert: "Programmation suspendue : #{error.message} Le programme reste sélectionné."
  end

  def redirect_to_selected_intent(schedule)
    notice = if schedule
               "Programmation Kaffeine confirmée (n° #{schedule.key})."
             else
               "Programme sélectionné, mais chaîne non reliée à Kaffeine."
             end

    redirect_to tv_guide_path(guide_params), notice:
  end

  def redirect_to_unscheduled_intent(error)
    Rails.logger.warn("Kaffeine scheduling rejected: #{error.class}: #{error.message}")
    redirect_to(
      tv_guide_path(guide_params),
      alert: "Programmation non confirmée : le programme reste sélectionné. Vérifiez Kaffeine avant de réessayer."
    )
  end

  def schedule_selected_intent(intent)
    channel = intent.broadcast_observation.guide_channel.channel
    return unless channel&.kaffeine_name.present?

    Tv::RecordingIntentScheduler.new(
      recording_intent: intent,
      client: Tv::KaffeineDbus.new
    ).call
  end

  def cancel_intent(intent)
    Tv::RecordingIntentScheduleCanceller.new(
      recording_intent: intent,
      client: Tv::KaffeineDbus.new
    ).call
  end

  def redirect_to_cancelled_intent
    redirect_to(
      recording_intent_redirect_path,
      notice: "L’enregistrement programmé a été annulé."
    )
  end

  def redirect_to_blocked_cancellation(error)
    Rails.logger.warn("Kaffeine cancellation rejected: #{error.class}: #{error.message}")
    redirect_to(
      recording_intent_redirect_path,
      alert: "Annulation non confirmée : vérifiez la programmation dans Kaffeine."
    )
  end

  def selected_recording_intents
    Tv::RecordingIntent.status_selected
                       .includes(
                         :kaffeine_schedule_link,
                         broadcast_observation: { guide_channel: %i[channel guide_source] }
                       )
                       .order(:programme_starts_at, :id)
  end

  def guide_params
    params.permit(
      :date,
      :guide_source_id,
      :zoom,
      :all_channels
    )
  end

  def recording_intent_redirect_path
    return tv_recording_intents_path \
      if params[:return_to] == "index"

    tv_guide_path(guide_params)
  end
end
