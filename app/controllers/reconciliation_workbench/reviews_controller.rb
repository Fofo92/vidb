module ReconciliationWorkbench
  class ReviewsController < ApplicationController
    before_action :authenticate_user!

    def index
      prepare_filters
      scope = ReviewQuery.new(axis: @axis, state: @state, query: @query, tree_id: @tree_id).call
      prepare_page(scope)
    rescue ActiveRecord::RecordNotFound
      redirect_to reconciliation_workbench_reviews_path(axis: @axis), alert: 'Arbre introuvable.'
    end

    def create
      values = params.permit(:axis, :decision, :review_token, :comment, case_ids: [])
      parameters = { axis: values[:axis], ids: values[:case_ids], decision: values[:decision],
                     token: values[:review_token], comment: values[:comment] }
      receipt = CaseReview.new(user: current_user, parameters: parameters).call
      redirect_to reconciliation_workbench_reviews_path(return_filters), notice: review_notice(receipt)
    rescue ArgumentError => e
      redirect_to reconciliation_workbench_reviews_path(return_filters), alert: e.message
    end

    private

    def prepare_filters
      @axis = params[:axis] == 'disk' ? 'disk' : 'metadata'
      @state = ReviewQuery::STATES.include?(params[:state]) ? params[:state] : 'pending'
      @query = params[:q].to_s[0, 200]
      @tree_id = params[:tree_id].presence
    end

    def prepare_page(scope)
      @total = scope.count
      @page = params[:page].to_i.clamp(1, [(@total + 29) / 30, 1].max)
      @cases = scope.offset((@page - 1) * 30).limit(30).to_a
      @review_token = ReviewScope.issue(@cases, axis: @axis)
    end

    def return_filters
      params.permit(:axis, :state, :q, :tree_id, :page).to_h
    end

    def review_notice(receipt)
      return 'Ces décisions étaient déjà enregistrées.' if receipt[:count].zero?

      return "#{receipt[:count]} propositions classées, sans application." unless receipt[:run_id]

      "#{receipt[:count]} propositions validées ; application n° #{receipt[:run_id]} en attente."
    end
  end
end
