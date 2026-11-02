# frozen_string_literal: true

# A suspicion report, never a merge plan or a file-content duplicate detector.
class RecordDuplicateReview
  def initialize(records: Record.all, assets: VideoAsset.all)
    @records = records.to_a
    @index = @records.index_by(&:id)
    @assets = assets.to_a.group_by(&:record_id)
  end

  def call
    @records.group_by { |record| key(record) }.filter_map do |identity, records|
      next unless identity && records.size > 1

      { records: records, copies: records.to_h { |record| [record.id, @assets.fetch(record.id, [])] } }
    end
  end

  private

  def normalized(value)
    value.to_s.parameterize(separator: ' ')
  end

  def key(record)
    title = normalized(record.french_title.presence || record.original_title)
    return if title.blank?

    [record.record_kind, title, record.year, context(record)]
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
    [parent.record_kind, title, parent.year, parent.rank]
  end
end
