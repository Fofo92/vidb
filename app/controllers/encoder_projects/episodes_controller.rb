module EncoderProjects
  class EpisodesController < ApplicationController
    before_action :load_scope

    def show
      @episode = EpisodeRequest.new(@scope.fetch('project'))
      @query = params[:q].presence || @episode.series
      @series = Record.where(record_kind: 'series').where(
        'french_title ILIKE :q OR original_title ILIKE :q', q: "%#{Record.sanitize_sql_like(@query)}%"
      ).order(:french_title).limit(30)
    end

    def create
      record = create_and_bind
      redirect_to record_path(record), notice: 'Épisode prêt. Reprends l’identification dans video_encoder.'
    rescue ArgumentError, ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound,
           ActiveRecord::SoleRecordExceeded => e
      redirect_to encoder_projects_episode_path(request_token: params[:request_token], q: params[:q]), alert: e.message
    end

    private

    def create_and_bind
      Record.transaction do
        record = EpisodeCreation.new.call(project: @scope.fetch('project'), series_id: params.require(:series_id),
                                          title: params[:title], year: parsed_year, source: params[:source])
        EpisodeBinding.new(user: current_user, url: request.base_url).call(@scope.fetch('project'), record)
        record
      end
    end

    def parsed_year
      Integer(params[:year], 10) if params[:year].present?
    end

    def load_scope
      @scope = CatalogueScope.read(params[:request_token], user: current_user)
    rescue ArgumentError, KeyError
      render plain: 'Lien expiré ou autre compte : relance l’identification.', status: :unprocessable_content
    end
  end
end
