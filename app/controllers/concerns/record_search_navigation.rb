# frozen_string_literal: true

module RecordSearchNavigation
  private

  def paginate_records(results)
    last_page = [(@result_count.to_f / Record.default_per_page).ceil, 1].max
    page = params[:page].to_i.clamp(1, last_page)
    results.includes(:ratings).order(:french_title, :id).page(page)
  end

  def search_return_path
    query = RecordSearchContext.query(params[:search_context], user: current_user)
    records_path(query) if query
  end

  def invalidate_record_search
    Rails.cache.delete('record-metadata-filter-v3')
  end
end
