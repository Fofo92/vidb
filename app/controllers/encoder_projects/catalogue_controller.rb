module EncoderProjects
  class CatalogueController < ApplicationController
    before_action :load_scope

    def show
      @query = params[:q].presence || File.basename(@scope.fetch('project').fetch('output_path'), '.mkv')
      @candidates = FilmCatalogue.new.call(@query)
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
      redirect_to record_path(record),
                  notice: 'Fiche prête et associée au montage. Reprends l’identification dans video_encoder.'
    rescue ArgumentError, ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound,
           ActiveRecord::SoleRecordExceeded => e
      redirect_to encoder_projects_catalogue_path(request_token: params[:request_token]), alert: e.message
    end

    private

    def load_scope
      @scope = CatalogueScope.read(params[:proposal_token].presence || params[:request_token], user: current_user)
    rescue ArgumentError, KeyError
      render plain: 'Lien expiré ou autre compte : relance l’identification depuis video_encoder.',
             status: :unprocessable_content
    end

    def selected_ids(name)
      Array(params[name]).reject(&:blank?).map { |value| Integer(value, 10) }.uniq
    end
  end
end
