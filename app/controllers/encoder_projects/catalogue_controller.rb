module EncoderProjects
  class CatalogueController < ApplicationController
    before_action :load_scope
    before_action :route_episode, only: :show

    def show
      @query = params[:q].presence || File.basename(@scope.fetch('project').fetch('output_path'), '.mkv')
      @series_candidates = SeriesCatalogueSearch.new.call(@query)
      load_films
      @genders = Gender.order(:name)
      @countries = Country.order(:long_name)
    rescue ArgumentError, KeyError, JSON::ParserError, CatalogEnrichment::TmdbClient::Error,
           IOError, SystemCallError, Timeout::Error => e
      @search_error = e.message
      @candidates = []
    end

    def create
      record = CatalogueCreation.new(user: current_user, url: request.base_url).call(
        scope: @scope, gender_ids: selected_ids(:gender_ids), country_ids: selected_ids(:country_ids)
      )
      prepared = params[:encoder_window] == '1' ? 1 : nil
      redirect_to record_path(record, encoder_prepared: prepared),
                  notice: 'Fiche prête et associée au montage. Reprends l’identification dans video_encoder.'
    rescue ArgumentError, ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound,
           ActiveRecord::SoleRecordExceeded => e
      redirect_to encoder_projects_catalogue_path(request_token: params[:request_token]), alert: e.message
    end

    private

    def load_films
      catalogue = FilmCatalogue.new
      @candidates = catalogue.call(@query)
      @source_warnings = catalogue.warnings
    end

    def load_scope
      @scope = CatalogueScope.read(params[:proposal_token].presence || params[:request_token], user: current_user)
    rescue ArgumentError, KeyError
      render plain: 'Lien expiré ou autre compte : relance l’identification depuis video_encoder.',
             status: :unprocessable_content
    end

    def route_episode
      original = @scope.fetch('project')
      project = EpisodeRequest.with_query(original, params[:q])
      return unless EpisodeRequest.match?(project)

      token = if project == original
                params[:request_token]
              else
                CatalogueScope.issue(user: current_user, project: project)
              end
      redirect_to encoder_projects_episode_path(request_token: token)
    end

    def selected_ids(name)
      Array(params[name]).reject(&:blank?).map { |value| Integer(value, 10) }.uniq
    end
  end
end
