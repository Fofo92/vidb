# frozen_string_literal: true

# A suspicion report, never a merge plan or a file-content duplicate detector.
class RecordDuplicateReview
  def initialize(records: Record.all, assets: VideoAsset.all)
    @records = records.to_a
    @index = @records.index_by(&:id)
    @episode_start_years = episode_start_years
    @assets = assets.to_a.group_by(&:record_id)
  end

  def call
    @records.group_by { |record| key(record) }.filter_map do |identity, records|
      next unless identity && records.size > 1

      {
        records: records,
        years: records.to_h { |record| [record.id, comparison_year(record)] },
        copies: records.to_h { |record| [record.id, @assets.fetch(record.id, [])] }
      }
    end
  end

  private

  def episode_start_years
    @records.each_with_object({}) do |record, years|
      next unless record.record_kind == 'episode' && record.year

      record.ancestor_ids.each do |id|
        years[id] = [years.fetch(id, record.year), record.year].min
      end
    end
  end

  def comparison_year(record)
    if %w[series season].include?(record.record_kind)
      @episode_start_years.fetch(record.id, record.year)
    else
      record.year
    end
  end

  def normalized(value)
    value.to_s.parameterize(separator: ' ')
  end

  def key(record)
    title = normalized(record.french_title.presence || record.original_title)
    year = comparison_year(record)
    return if title.blank? || year.nil?

    [record.record_kind, title, year, context(record)]
  end

  def context(record)
    parents = record.ancestor_ids.filter_map { |id| @index[id] }
    return unless %w[episode season].include?(record.record_kind) || parents.any? do |parent|
      parent.record_kind == 'series'
    end

    [parents.map { |parent| parent_key(parent) }, record.rank]
  end

  def parent_key(parent)
    title = normalized(parent.french_title.presence || parent.original_title)
    [parent.record_kind, title, comparison_year(parent), parent.rank]
  end
end
