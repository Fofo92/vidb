module EncoderProjects
  class EpisodesController < ApplicationController
    before_action :load_scope

    def show
      @episode = EpisodeRequest.new(@scope.fetch('project'))
      @query = params[:q].presence || @episode.series
      @series = Record.where(record_kind: 'series').where(
        'french_title ILIKE :q OR original_title ILIKE :q', q: "%#{Record.sanitize_sql_like(@query)}%"
      ).order(:french_title).limit(30)
      @unqualified_series = unqualified_series
      prepare_proposals
    end

    def create
      record = create_and_bind
      prepared = params[:encoder_window] == '1' ? 1 : nil
      redirect_to record_path(record, encoder_prepared: prepared),
                  notice: 'Épisode prêt. Reprends l’identification dans video_encoder.'
    rescue ArgumentError, KeyError, CatalogEnrichment::TmdbClient::Error, ActiveRecord::RecordInvalid,
           ActiveRecord::RecordNotFound, ActiveRecord::SoleRecordExceeded => e
      failed_submission(e)
    end

    private

    def create_and_bind
      EpisodePreparation.new(user: current_user, url: request.base_url).call(
        scope: @scope, parameters: enrichment_parameters, series_id: params[:series_id]
      )
    end

    def failed_submission(error)
      @episode = EpisodeRequest.new(@scope.fetch('project'))
      @query = params[:q].presence || @episode.series
      @series = Record.where(record_kind: 'series', id: params[:series_id])
      @unqualified_series = unqualified_series
      @proposals = [@scope['candidate'] || {}]
      @submitted = enrichment_parameters
      @warnings = [error.message]
      render :show, status: :unprocessable_content
    end

    def enrichment_parameters
      params.permit(:title, :original_title, :year, :source, :abstract, :language_version,
                    gender_ids: [], country_ids: []).to_h
    end

    def prepare_proposals
      @proposals = []
      @warnings = []
      return prepare_missing_series if missing_series_lookup?

      series = selected_series
      return unless series

      candidates = consult_sources? ? external_proposals(series) : []
      @proposals = (candidates.presence || [{}]).map { |item| EpisodeDefaults.call(series, @episode, item) }
    end

    def unqualified_series
      Record.where(record_kind: 'undetermined', ancestry: nil).where(
        'french_title ILIKE :q OR original_title ILIKE :q', q: "%#{Record.sanitize_sql_like(@query)}%"
      ).order(:french_title).limit(10)
    end

    def selected_series
      @series.find { |record| record.id.to_s == params[:series_id] } || (@series.sole if @series.one?)
    end

    def missing_series_lookup?
      @series.empty? || params[:external_series] == '1'
    end

    def prepare_missing_series
      catalogue = MissingSeriesCatalogue.new
      @proposals = catalogue.call(@query, @episode)
      @warnings = catalogue.warnings
      @warnings << 'Aucune proposition exploitable : précise le titre de la série.' if @proposals.empty?
    end

    def consult_sources?
      params[:enrich] == '1' || (@series.one? && params[:enrich] != '0')
    end

    def external_proposals(series)
      catalogue = EpisodeCatalogue.new
      proposals = catalogue.call(series, @episode)
      @warnings = catalogue.warnings
      @warnings << 'Sources incomplètes : tu peux renseigner les champs signalés à compléter.' if proposals.empty?
      proposals
    end

    def load_scope
      @scope = CatalogueScope.read(params[:proposal_token].presence || params[:request_token], user: current_user)
    rescue ArgumentError, KeyError
      render plain: 'Lien expiré ou autre compte : relance l’identification.', status: :unprocessable_content
    end
  end
end
