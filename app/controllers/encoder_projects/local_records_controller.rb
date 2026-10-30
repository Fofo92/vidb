module EncoderProjects
  class LocalRecordsController < ApplicationController
    before_action :authenticate_user!
    before_action :load_scope

    def show
      @query = params[:q].presence || File.basename(@scope.fetch('project').fetch('output_path'), '.mkv')
      @records = LocalRecordSearch.new.call(@query, host: request.host)
    end

    def create
      record = LocalRecordSelection.call(user: current_user, url: request.base_url,
                                         project: @scope.fetch('project'), record: Record.find(params[:record_id]),
                                         confirmed: params[:confirm_replacement] == '1')
      redirect_to record_path(record, encoder_prepared: 1), notice: 'Fiche existante associée au montage.'
    rescue ArgumentError, KeyError, ActiveRecord::RecordNotFound, ActiveRecord::SoleRecordExceeded => e
      redirect_to encoder_projects_local_records_path(request_token: params[:request_token], q: params[:q]),
                  alert: e.message
    end

    private

    def load_scope
      @scope = CatalogueScope.read(params[:request_token], user: current_user)
    rescue ArgumentError, KeyError
      render plain: 'Lien expiré ou autre compte : relance l’identification depuis video_encoder.',
             status: :unprocessable_content
    end
  end
end
