class RecordSearchController < ApplicationController
  def show
    @q = Record.ransack(params[:q])
    render layout: false
  end

  def results
    prepare_results
    render layout: false
  rescue ActiveRecord::RecordNotFound
    render_search_error
  end

  private

  def prepare_results
    @q = Record.ransack(params[:q])
    results = RecordIndexFilter.new(filter_params, scope: @q.result, user: current_user).call
    @total = results.count
    @records = results.order(:french_title, :id).limit(10)
    query = request.query_parameters.slice('q', 'filters')
    @record_search_context_token = RecordSearchContext.issue(user: current_user, query: query)
    @results_url = records_path(query)
  end

  def render_search_error
    @error = 'Critère invalide ou arbre introuvable.'
    @records = Record.none
    @total = 0
    @results_url = records_path(request.query_parameters.slice('q', 'filters'))
    render :results, layout: false, status: :unprocessable_content
  end

  def filter_params
    params.fetch(:filters, ActionController::Parameters.new)
          .permit(:country_id, :gender_id, :language_version_id, :medium_id,
                  :year, :record_kind, :tree_id, :display, :missing, :review, :completeness, :rating)
  end
end
