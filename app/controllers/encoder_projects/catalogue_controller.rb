module EncoderProjects
  class CatalogueController < ApplicationController
    before_action :load_scope
    before_action :load_completion_record, only: :show
    before_action :select_work_kind, only: :show
    before_action :route_episode, only: :show

    def show
      @query = params[:q].presence || @completion_record&.french_title.presence ||
               File.basename(@scope.fetch('project').fetch('output_path'), '.mkv')
      @series_candidates = standalone_work? ? [] : SeriesCatalogueSearch.new.call(@query)
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
        scope: @scope, gender_ids: selected_ids(:gender_ids), country_ids: selected_ids(:country_ids),
        confirmed: params[:confirm_replacement] == '1'
      )
      prepared = params[:encoder_window] == '1' ? 1 : nil
      redirect_to record_path(record, encoder_prepared: prepared), notice: completion_notice
    rescue ArgumentError, ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound,
           ActiveRecord::SoleRecordExceeded => e
      redirect_to encoder_projects_catalogue_path(request_token: params[:request_token]), alert: e.message
    end

    private

    def completion_notice
      if @scope.dig('project', 'completion_record_id')
        return 'Fiche mise à jour. Reprends la préparation dans video_encoder.'
      end

      'Fiche prête et associée au montage. Reprends l’identification dans video_encoder.'
    end

    def standalone_work?
      @completion_record.present? || @scope.fetch('project')['work_kind'] == 'standalone_video'
    end

    def load_completion_record
      project = @scope.fetch('project')
      return unless project['completion_record_id']

      @completion_record = ExistingFilmCompletion.bound_record!(project)
      @replacement_token = replacement_token(project)
    rescue ArgumentError, ActiveRecord::RecordNotFound => e
      render plain: e.message, status: :unprocessable_content
    end

    def replacement_token(project)
      binding = Binding.current(project.fetch('project_id'))
      return unless binding && binding['record_id'] == @completion_record.id

      revision = project.except('completion_record_id').merge('replace_binding' => binding)
      CatalogueScope.issue(user: current_user, project: revision)
    end

    def select_work_kind
      return if @completion_record

      url = FilmCatalogue.tmdb_movie_url(params[:q])
      return unless url || params[:work_kind] == 'standalone_video'

      project = @scope.fetch('project').except('episode_target', 'episode_search')
                      .merge('work_kind' => 'standalone_video', 'explicit_tmdb_movie_url' => url)
      @scope = @scope.merge('project' => project, 'candidate' => nil)
      params[:request_token] = CatalogueScope.issue(user: current_user, project: project)
      params[:q] = url if url
    end

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
      return if standalone_work?

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
