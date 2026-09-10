class RecordHierarchyParentSearch
  def initialize(record:, query:)
    @record = record
    @query = query
  end

  def results
    return Record.none if normalized_query.blank?

    matching_records.order(:french_title, :original_title, :id)
  end

  def records_outside_current_branch
    records = Record.where.not(
      id: @record.subtree.select(:id)
    )
    return records unless @record.parent_id

    records.where.not(id: @record.parent_id)
  end

  private

  def matching_records
    records_outside_current_branch
      .where(record_kind: allowed_parent_kinds)
      .where(title_matches)
  end

  def allowed_parent_kinds
    Record.allowed_parent_kinds_for_hierarchy(@record.record_kind)
  end

  def title_matches
    [
      <<~SQL.squish,
        french_title ILIKE :pattern
        OR original_title ILIKE :pattern
      SQL
      { pattern: search_pattern }
    ]
  end

  def normalized_query
    @normalized_query ||= @query.to_s.strip
  end

  def search_pattern
    escaped_query = ActiveRecord::Base.sanitize_sql_like(
      normalized_query
    )

    "%#{escaped_query}%"
  end
end
