class TvRecordingIntentCorrectionsController < ApplicationController
  ERRORS = [
    Tv::RecordingScheduleCorrection::Conflict, Tv::KaffeineScheduleManager::Error,
    Tv::KaffeineCommandRunner::CommandError, Tv::KaffeineScheduleParser::InvalidResponse,
    Tv::KaffeineScheduleLock::Busy, Tv::MultiplexCapacityGuard::Warning, Tv::KaffeineDbus::ScheduleRejected,
    ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique, SystemCallError
  ].freeze

  before_action :load_correction

  def edit
    @current = @correction.snapshot
  rescue *ERRORS => e
    reject_correction(e)
  end

  def create
    if params[:confirmation].present?
      @correction.apply(params[:confirmation])
      redirect_to tv_recording_intents_path, notice: 'Programmation vérifiée et actualisée.'
    else
      @current, @desired, @confirmation = @correction.preview(params[:mode], manual_fields)
      render :edit
    end
  rescue *ERRORS => e
    reject_correction(e)
  end

  private

  def load_correction
    @intent = Tv::RecordingIntent.find(params[:tv_recording_intent_id])
    @correction = Tv::RecordingScheduleCorrection.new(intent: @intent)
  end

  def manual_fields
    params.permit(:name, :channel, :starts_at, :ends_at).to_h
  end

  def reject_correction(error)
    Rails.logger.warn("TV correction rejected: #{error.class}: #{error.message}")
    message = if user_facing_error?(error)
                error.message
              else
                'Correction non confirmée. Relis le tableau et vérifie la programmation dans Kaffeine.'
              end
    redirect_to tv_recording_intents_path(state: 'review'), alert: message
  end

  def user_facing_error?(error)
    error.is_a?(Tv::RecordingScheduleCorrection::Conflict) || error.is_a?(Tv::MultiplexCapacityGuard::Warning)
  end
end
