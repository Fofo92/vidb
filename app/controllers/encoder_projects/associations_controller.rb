module EncoderProjects
  class AssociationsController < ApplicationController
    before_action :authenticate_user!
    before_action :load_scope

    def show
      @cases = project_cases.where(status: %w[pending blocked]).order(id: :desc).to_a
                            .uniq { |item| item.payload['record_id'] }
      @review_token = ReconciliationWorkbench::ReviewScope.issue(@cases, axis: 'metadata')
    end

    def create
      item = project_cases.find(params[:case_id])
      record = CandidateAssociation.call(user: current_user, item: item, token: params[:review_token])
      redirect_to record_path(record, encoder_prepared: 1), notice: 'Fiche associée au montage.'
    rescue ArgumentError, KeyError, ActiveRecord::RecordNotFound => e
      redirect_to encoder_projects_association_path(request_token: params[:request_token]), alert: e.message
    end

    private

    def project_cases
      ReconciliationCase.current.where(rule_key: ReconciliationWorkbench::Rules::ENCODER_PROJECT.key)
                        .where("payload ->> 'project_id' = ?", @scope.fetch('project').fetch('project_id'))
    end

    def load_scope
      @scope = CatalogueScope.read(params[:request_token], user: current_user)
    rescue ArgumentError, KeyError
      render plain: 'Lien expiré ou autre compte : relance l’identification.', status: :unprocessable_content
    end
  end
end
