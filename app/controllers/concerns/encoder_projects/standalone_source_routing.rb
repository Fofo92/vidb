module EncoderProjects
  module StandaloneSourceRouting
    extend ActiveSupport::Concern

    included do
      before_action :route_standalone_source, only: :show
    end

    private

    def route_standalone_source
      url = FilmCatalogue.tmdb_movie_url(params[:source_url]) || FilmCatalogue.tmdb_movie_url(params[:q])
      return unless url

      token = params[:proposal_token].presence || params[:request_token]
      redirect_to encoder_projects_catalogue_path(request_token: token, q: url, work_kind: 'standalone_video',
                                                  encoder_window: params[:encoder_window])
    end
  end
end
