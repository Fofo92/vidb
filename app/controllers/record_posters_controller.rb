# frozen_string_literal: true

class RecordPostersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_record
  before_action :require_film_review, only: %i[review preview preview_image confirm]

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
    return redirect_to_film_review if result == :unidentified && RecordPosters::FilmConfirmation.supported?(@record)

    message = { attached: 'Pochette récupérée.', preserved: 'Pochette déjà conservée.',
                absent: 'Aucune pochette proposée par TMDB.',
                unidentified: 'Identification TMDB insuffisante : aucune nouvelle pochette récupérée.' }.fetch(result)
    redirect_to record_path(@record), notice: message
  rescue RecordPosters::Fetch::Error, RecordPosters::ImageDownload::Error,
         RecordPosters::Store::Error, CatalogEnrichment::TmdbClient::Error => e
    redirect_to record_path(@record), alert: e.message
  end

  def review
    @review = RecordPosters::FilmReview.new.call(@record)
  rescue CatalogEnrichment::TmdbClient::Error
    @review = { message: 'Recherche TMDB indisponible. Tu peux réessayer ou indiquer un lien direct.', candidates: [] }
  end

  def preview
    @confirmation = RecordPosters::FilmConfirmation.new.preview(@record, url: params[:tmdb_url])
  rescue RecordPosters::FilmConfirmation::Error, CatalogEnrichment::TmdbClient::Error => e
    redirect_to review_record_poster_path(@record), status: :see_other, alert: e.message
  end

  def preview_image
    bytes = RecordPosters::FilmConfirmation.new.preview_image(@record, token: params[:confirmation_token])
    image = RecordPosters::Store.image_attributes(bytes)
    response.headers['Cache-Control'] = 'no-store'
    send_data bytes, type: image.fetch(:content_type), disposition: 'inline'
  rescue RecordPosters::FilmConfirmation::Error, RecordPosters::ImageDownload::Error, RecordPosters::Store::Error
    head :not_found
  end

  def confirm
    result = RecordPosters::FilmConfirmation.new.confirm(@record, token: params[:confirmation_token])
    notice = result == :attached ? 'Pochette récupérée avec la référence confirmée.' : 'Pochette existante conservée.'
    redirect_to record_path(@record), status: :see_other, notice: notice
  rescue RecordPosters::FilmConfirmation::Error, RecordPosters::ImageDownload::Error,
         RecordPosters::Store::Error, ActiveRecord::RecordInvalid => e
    redirect_to review_record_poster_path(@record), status: :see_other, alert: e.message
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

  def redirect_to_film_review
    message = 'Aucune nouvelle pochette récupérée : vérifie les propositions TMDB.'
    redirect_to review_record_poster_path(@record), status: :see_other, notice: message
  end

  def require_film_review
    return if RecordPosters::FilmConfirmation.supported?(@record)

    redirect_to record_path(@record), alert: 'Cette recherche de pochette concerne les vidéos autonomes.'
  end

  def set_record
    @record = Record.find(params[:record_id])
  end
end
