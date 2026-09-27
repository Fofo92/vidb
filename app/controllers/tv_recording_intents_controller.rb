class TvRecordingIntentsController < ApplicationController
  def index
    @recording_intents = selected_recording_intents
    @recording_intents_by_date = recording_intents_by_date
  end

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
    cancel_intent(intent)
    redirect_to_cancelled_intent
  rescue Tv::RecordingIntentScheduleCanceller::LinkedScheduleMismatch,
         Tv::RecordingIntentScheduleCanceller::TooLateToCancel,
         Tv::KaffeineScheduleManager::VerificationError,
         Tv::KaffeineCommandRunner::CommandError,
         Tv::KaffeineScheduleParser::InvalidResponse,
         Tv::KaffeineScheduleLock::Busy
    redirect_to_blocked_cancellation
  end

  private

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

  def redirect_to_blocked_cancellation
    redirect_to(
      recording_intent_redirect_path,
      alert: "Annulation non confirmée : vérifiez la programmation dans Kaffeine."
    )
  end

  def selected_recording_intents
    Tv::RecordingIntent.status_selected
                       .includes(
                         :kaffeine_schedule_link,
                         broadcast_observation: { guide_channel: :channel }
                       )
                       .order(:programme_starts_at, :id)
  end

  def recording_intents_by_date
    @recording_intents
      .group_by { |intent| recording_date(intent) }
      .transform_values { |intents| sort_recording_intents(intents) }
  end

  def recording_date(intent)
    intent.programme_starts_at
          .in_time_zone("Europe/Paris")
          .to_date
  end

  def sort_recording_intents(intents)
    intents.sort_by { |intent| recording_intent_sort_key(intent) }
  end

  def recording_intent_sort_key(intent)
    channel = intent.broadcast_observation.guide_channel.channel

    [
      channel&.logical_number || Float::INFINITY,
      intent.programme_starts_at,
      intent.id
    ]
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
