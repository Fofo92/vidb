class DvdContentsController < ApplicationController
  before_action :load_edition

  def edit
    @episodes = @edition.record.subtree.where(record_kind: %w[episode standalone_video])
    @contents = @edition.dvd_contents.index_by(&:record_id)
    @languages = LanguageVersion.order(:long_name)
  end

  def update
    raise ArgumentError, "Sélection non transmise." unless params[:content_selection] == "1"

    DvdContentSelection.new.call(edition: @edition, rows: content_rows)
    redirect_to dvd_scan_path(ean: @edition.ean), status: :see_other, notice: "Contenu possédé enregistré."
  rescue ArgumentError, ActiveRecord::ActiveRecordError => e
    redirect_to edit_dvd_edition_contents_path(@edition), status: :see_other, alert: e.message
  end

  private

  def load_edition
    @edition = DvdEdition.find(params[:dvd_edition_id])
  end

  def content_rows
    permitted = episode_rows.index_with { %i[selected language_version_id audio_languages subtitle_languages] }
    params.fetch(:contents, ActionController::Parameters.new)
          .permit(permitted)
  end

  def episode_rows
    @edition.record.subtree.where(record_kind: %w[episode standalone_video]).pluck(:id).map(&:to_s)
  end
end
