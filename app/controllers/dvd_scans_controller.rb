class DvdScansController < ApplicationController
  def show
    @ean = params[:ean].to_s.strip
    return if @ean.empty?

    return invalid_ean unless DvdEdition.valid_ean?(@ean)

    @edition = DvdEdition.find_by(ean: @ean)
    return if @edition

    load_external_titles if params[:lookup] == "1" || params[:scan].present?
    load_record_choices
  end

  def create
    ean = params[:ean].to_s.strip
    return redirect_to dvd_scan_path(ean: ean), status: :see_other unless DvdEdition.valid_ean?(ean)

    record = Record.find(params[:record_id])
    edition = DvdEdition.create_or_find_by!(ean: ean) { |entry| entry.record = record }
    redirect_to dvd_scan_path(ean: ean), notice: attachment_notice(edition, record), status: :see_other
  end

  private

  def invalid_ean
    flash.now[:alert] = "Le code saisi doit être un EAN-13 valide."
  end

  def load_external_titles
    @external_titles = DvdBarcodeLookup.new.call(@ean)
  rescue DvdBarcodeLookup::Error
    @external_lookup_failed = true
  end

  def load_record_choices
    @record = Record.find(params[:record_id]) if params[:record_id].present?
    @title = params[:title].to_s.strip.presence || automatic_work_title
    return if @record || @title.empty?

    pattern = "%#{Record.sanitize_sql_like(@title)}%"
    load_catalogue_choices if params[:catalogue] == "1" || @automatic_work_title
    @records = Record.where("french_title ILIKE :pattern OR original_title ILIKE :pattern", pattern: pattern)
                     .order(:french_title, :id).limit(30)
  end

  def automatic_work_title
    return "" unless @external_titles&.one?

    @automatic_work_title = helpers.dvd_work_query(@external_titles.first).first
  end

  def load_catalogue_choices
    @catalogue_choices = series_catalogue_choices
    @catalogue_choices.concat(EncoderProjects::FilmCatalogue.new.call(@title))
  rescue ArgumentError, KeyError, JSON::ParserError, CatalogEnrichment::TmdbClient::Error,
         IOError, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError, SocketError
    @catalogue_incomplete = true
  end

  def series_catalogue_choices
    EncoderProjects::SeriesCatalogueSearch.new.call(@title, raise_errors: true).map { |series| series_candidate(series) }
  rescue CatalogEnrichment::TmdbClient::Error => e
    @tmdb_series_error = e.message
    []
  rescue ArgumentError, KeyError, JSON::ParserError, IOError, SystemCallError,
         Timeout::Error, OpenSSL::SSL::SSLError, SocketError
    @tmdb_series_error = "Recherche de séries indisponible."
    []
  end

  def series_candidate(series)
    { "french_title" => series["title"], "original_title" => series["original_title"],
      "year" => series["year"], "record_kind" => "series", "tmdb_series_id" => series.fetch("tmdb_id"),
      "source" => { "url" => "https://www.themoviedb.org/tv/#{series.fetch('tmdb_id')}" } }
  end

  def attachment_notice(edition, record)
    return "Édition DVD associée à la fiche." if edition.record_id == record.id

    "Ce code est déjà associé à une autre fiche."
  end
end
