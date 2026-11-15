module RecordFiltersHelper
  def record_filter_options(field)
    case field
    when :country_id then Country.order(:long_name).pluck(:long_name, :id)
    when :gender_id then Gender.order(:name).pluck(:name, :id)
    when :language_version_id then LanguageVersion.order(:short_name).pluck(:short_name, :id)
    when :medium_id then Medium.order(:short_name).pluck(:short_name, :id)
    when :record_kind then RecordsHelper::RECORD_KIND_LABELS.map { |value, label| [label, value] }
    when :completeness then [["Complets", "complete"], ["Incomplets", "incomplete"], ["Indéterminés", "unknown"]]
    when :missing then RecordMetadataAudit::LABELS.map { |value, label| [label, value] }
    end
  end

  def record_filter_value(field)
    params.fetch(:filters, {})[field]
  end

  def record_search_filter_count
    fields = %i[country_id gender_id language_version_id medium_id year record_kind tree_id missing completeness]
    count = fields.count { |field| record_filter_value(field).present? }
    count += 1 if record_filter_value(:review) == '1'
    count += 1 if %w[trees roots].include?(record_filter_value(:display))
    count
  end

  def record_search_menu_path
    query = RecordSearchContext.query(params[:search_context], user: current_user) || {}
    query = request.query_parameters if controller_name == 'records' && action_name == 'index'
    record_search_path(query.except('page'))
  end

  def record_filter_parent(record)
    links = record.ancestors.map do |parent|
      link_to(parent.id, records_path(filters: { tree_id: parent.id }),
              title: parent.complete_title, aria: { label: "Parent #{parent.id} : #{parent.complete_title}" })
    end
    safe_join(links, " / ")
  end
end
