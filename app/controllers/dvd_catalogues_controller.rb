class DvdCataloguesController < ApplicationController
  def show
    @edition = DvdEdition.find_by!(ean: params[:ean])
    @query = params[:title].presence || @edition.record.french_title.presence || @edition.record.original_title
    @choices = EncoderProjects::SeriesCatalogueSearch.new.call(@query, raise_errors: true)
  rescue CatalogEnrichment::TmdbClient::Error, ArgumentError, KeyError, JSON::ParserError,
         IOError, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError, SocketError => e
    @choices = []
    flash.now[:alert] = "Recherche indisponible : #{e.message}"
  end

  def create
    edition = DvdSeriesImport.new.call(ean: params[:ean].to_s.strip, series_id: params[:tmdb_series_id])
    redirect_to edit_dvd_edition_contents_path(edition), status: :see_other,
                                                         notice: "Catalogue complété. Confirme le contenu du coffret."
  rescue ArgumentError, KeyError, ActiveRecord::ActiveRecordError, CatalogEnrichment::TmdbClient::Error,
         JSON::ParserError, IOError, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError, SocketError => e
    redirect_to dvd_scan_path(ean: params[:ean]), status: :see_other,
                                                  alert: "Catalogue non importé : #{e.message}"
  end
end
