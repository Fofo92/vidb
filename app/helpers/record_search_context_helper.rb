# frozen_string_literal: true

module RecordSearchContextHelper
  def record_search_context_token
    @record_search_context_token ||= build_record_search_context
  end

  def record_search_return_path
    query = RecordSearchContext.query(params[:search_context], user: current_user)
    query ? records_path(query) : records_path
  end

  private

  def build_record_search_context
    if controller_name == 'records' && action_name == 'index'
      query = request.query_parameters.merge('page' => @records.current_page.to_s)
      RecordSearchContext.issue(user: current_user, query: query)
    else
      token = params[:search_context]
      token if RecordSearchContext.query(token, user: current_user)
    end
  end
end
