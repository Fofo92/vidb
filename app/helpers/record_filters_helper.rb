module RecordFiltersHelper
  def record_filter_options(field)
    case field
    when :country_id then Country.order(:long_name).pluck(:long_name, :id)
    when :gender_id then Gender.order(:name).pluck(:name, :id)
    when :language_version_id then LanguageVersion.order(:short_name).pluck(:short_name, :id)
    when :medium_id then Medium.order(:short_name).pluck(:short_name, :id)
    when :record_kind then RecordsHelper::RECORD_KIND_LABELS.map { |value, label| [label, value] }
    when :missing then RecordMetadataAudit::LABELS.map { |value, label| [label, value] }
    end
  end

  def record_filter_value(field)
    params.fetch(:filters, {})[field]
  end

  def record_filter_parent(record)
    links = record.ancestors.map do |parent|
      link_to(parent.complete_title, records_path(filters: { tree_id: parent.id }))
    end
    safe_join(links, " / ")
  end
end
