module EncoderProjects
  class EpisodesController < ApplicationController
    before_action :load_scope

    def show
      select_episode_query
      select_episode_target
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

    def select_episode_query
      original = @scope.fetch('project')
      project = EpisodeRequest.with_query(original, params[:q])
      params[:q] = EpisodeRequest.new(project).series if project['episode_search'] == params[:q].to_s.strip
      return if project == original

      @scope = @scope.merge('project' => project, 'candidate' => nil)
      params[:request_token] = CatalogueScope.issue(user: current_user, project: project)
    end

    def select_episode_target
      return unless params.key?(:season_number) || params.key?(:episode_number)

      target = { 'season' => Integer(params[:season_number], 10),
                 'episode' => Integer(params[:episode_number], 10) }
      project = @scope.fetch('project').merge('episode_target' => target)
      EpisodeRequest.new(project)
      @scope = @scope.merge('project' => project, 'candidate' => nil)
      params[:request_token] = CatalogueScope.issue(user: current_user, project: project)
    rescue ArgumentError, TypeError
      @target_warning = 'Choisis une saison de 0 à 99 et un épisode de 1 à 999.'
    end

    def create_and_bind
      EpisodePreparation.new(user: current_user, url: request.base_url).call(
        scope: @scope, parameters: enrichment_parameters, series_id: params[:series_id]
      )
    end

    def failed_submission(error)
      @episode = EpisodeRequest.new(@scope.fetch('project'))
      params[:request_token] = CatalogueScope.issue(user: current_user, project: @scope.fetch('project'))
      @query = params[:q].presence || @episode.series
      @series = Record.where(record_kind: 'series', id: params[:series_id])
      @unqualified_series = unqualified_series
      @proposals = [@scope['candidate'] || {}]
      @submitted = enrichment_parameters
      number = format('S%<season>02d E%<episode>02d', season: @episode.season, episode: @episode.episode)
      @warnings = ["Préparation de #{number} : #{error.message}"]
      render :show, status: :unprocessable_content
    end

    def enrichment_parameters
      params.permit(:title, :original_title, :year, :source, :abstract, :language_version, :complete_catalogue,
                    gender_ids: [], country_ids: []).to_h
    end

    def prepare_proposals
      @proposals = []
      @warnings = []
      @tmdb_source_id = TmdbSeriesUrl.id(params[:source_url]) if params[:source_url].present?
      return prepare_missing_series if missing_series_lookup?

      series = selected_series
      return unless series

      candidates = consult_sources? ? external_proposals(series) : []
      @proposals = (candidates.presence || [{}]).map { |item| EpisodeDefaults.call(series, @episode, item) }
    rescue ArgumentError => e
      @warnings << e.message
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
      id = @tmdb_source_id || params[:tmdb_series_id]
      @proposals = id.present? ? catalogue.from_id(id, @episode) : catalogue.call(@query, @episode)
      @warnings = catalogue.warnings
      @warnings << 'Aucune proposition exploitable : précise le titre de la série.' if @proposals.empty?
    end

    def consult_sources?
      @tmdb_source_id || params[:enrich] == '1' || (@series.one? && params[:enrich] != '0')
    end

    def external_proposals(series)
      catalogue = EpisodeCatalogue.new
      proposals = catalogue.call(series, @episode, **(@tmdb_source_id ? { tmdb_series_id: @tmdb_source_id } : {}))
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
