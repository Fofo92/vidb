class TvRecordingConfirmationsController < ApplicationController
  def create
    intent = Tv::RecordingIntent.find(params[:tv_recording_intent_id])
    unless intent.recording_confirmable?
      return redirect_to(
        tv_recording_intents_path,
        alert: "Vérifiez d’abord que la capture est terminée et qu’un fichier existe."
      )
    end

    intent.update!(recording_verified_at: Time.current)
    redirect_to tv_recording_intents_path, notice: "Fichier confirmé. Les rediffusions seront signalées dans le guide."
  end

  def destroy
    intent = Tv::RecordingIntent.find(params[:tv_recording_intent_id])
    intent.update!(recording_verified_at: nil)
    redirect_to tv_recording_intents_path, notice: "Confirmation retirée."
  end
end
