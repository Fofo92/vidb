module EncoderProjects
  class EpisodesController < ApplicationController
    before_action :load_scope

    def show
      @episode = EpisodeRequest.new(@scope.fetch('project'))
      @query = params[:q].presence || @episode.series
      @series = Record.where(record_kind: 'series').where(
        'french_title ILIKE :q OR original_title ILIKE :q', q: "%#{Record.sanitize_sql_like(@query)}%"
      ).order(:french_title).limit(30)
      prepare_proposals
    end

    def create
      record = create_and_bind
      redirect_to record_path(record), notice: 'Épisode prêt. Reprends l’identification dans video_encoder.'
    rescue ArgumentError, ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound,
           ActiveRecord::SoleRecordExceeded => e
      failed_submission(e)
    end

    private

    def create_and_bind
      Record.transaction do
        enrichment = EpisodeEnrichment.new(candidate: @scope['candidate'], parameters: enrichment_parameters,
                                           project: @scope.fetch('project'))
        creator = EpisodeCreation.new(previous_title: @scope.dig('candidate', 'title'))
        record = creator.call(project: @scope.fetch('project'), series_id: params.require(:series_id),
                              **enrichment.creation_values)
        enrichment.call(record)
        EpisodeBinding.new(user: current_user, url: request.base_url).call(@scope.fetch('project'), record)
        record
      end
    end

    def failed_submission(error)
      @episode = EpisodeRequest.new(@scope.fetch('project'))
      @query = params[:q].presence || @episode.series
      @series = Record.where(record_kind: 'series', id: params[:series_id])
      @proposals = [@scope['candidate'] || {}]
      @submitted = enrichment_parameters
      @warnings = [error.message]
      render :show, status: :unprocessable_content
    end

    def enrichment_parameters
      params.permit(:title, :year, :source, :abstract, :language_version, gender_ids: [], country_ids: []).to_h
    end

    def prepare_proposals
      @proposals = []
      @warnings = []
      series = @series.find { |record| record.id.to_s == params[:series_id] } || (@series.sole if @series.one?)
      return unless series

      candidates = consult_sources? ? external_proposals(series) : []
      @proposals = (candidates.presence || [{}]).map { |item| EpisodeDefaults.call(series, @episode, item) }
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
