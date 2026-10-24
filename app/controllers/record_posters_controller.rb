# frozen_string_literal: true

class RecordPostersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_record

  def show
    poster = RecordPosters::Display.call(@record)
    return head :not_found unless poster

    send_data poster.image.download, type: poster.image.blob.content_type,
                                     disposition: 'inline', filename: poster.image.filename.to_s
  end

  def update
    upload = params.require(:poster).fetch(:image)
    raise RecordPosters::Store::Error, 'Choisis un fichier image' unless upload.respond_to?(:read)

    RecordPosters::Store.call(@record, bytes: upload.read(RecordPoster::MAX_BYTES + 1), source: { 'kind' => 'manual' })
    redirect_to record_path(@record), notice: 'Pochette enregistrée.'
  rescue RecordPosters::Store::Error, ActiveRecord::RecordInvalid => e
    redirect_to record_path(@record), alert: e.message
  end

  def fetch
    result = RecordPosters::Fetch.new.call(@record, restore: true)
    message = { attached: 'Pochette récupérée.', preserved: 'Pochette déjà conservée.',
                absent: 'Aucune pochette proposée par TMDB.',
                unidentified: 'Identification automatique insuffisante ; pochette conservée en attente.' }.fetch(result)
    redirect_to record_path(@record), notice: message
  rescue RecordPosters::Fetch::Error, RecordPosters::ImageDownload::Error,
         RecordPosters::Store::Error, CatalogEnrichment::TmdbClient::Error => e
    redirect_to record_path(@record), alert: e.message
  end

  def destroy
    poster = RecordPoster.create_or_find_by!(record_id: @record.id)
    blob = poster.image.blob
    poster.with_lock do
      poster.image.detach
      poster.update!(source: { 'kind' => 'manual' })
    end
    blob&.purge
    redirect_to record_path(@record), notice: 'Pochette personnelle retirée ; récupération automatique désactivée.'
  end

  private

  def set_record
    @record = Record.find(params[:record_id])
  end
end
