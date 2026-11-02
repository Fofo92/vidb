# frozen_string_literal: true

# Completeness is relative to known leaves, not an external catalogue's episode count.
class RecordCompleteness
  KINDS = %w[collection series season].freeze
  STATES = %w[complete incomplete unknown].freeze

  def initialize(records: Record.includes(:video_assets))
    @records = records.to_a
  end

  def ids(state)
    raise ActiveRecord::RecordNotFound, 'Complétude invalide' unless STATES.include?(state)

    counts.filter_map { |id, values| id if classification(values) == state }
  end

  private

  def counts
    parents = @records.filter_map { |record| record.ancestor_ids.last }.to_set
    containers = @records.select { |record| KINDS.include?(record.record_kind) || parents.include?(record.id) }
    result = containers.to_h { |record| [record.id, { total: 0, missing: 0, unknown: 0 }] }
    count_leaves(result)
    containers.reject { |record| parents.include?(record.id) }.each do |record|
      add_to_ancestors(result, record, nil)
    end
    result
  end

  def count_leaves(result)
    @records.each do |record|
      next if result.key?(record.id)

      present = VideoAssets::PartCoverage.available?(record.video_assets.to_a,
                                                     expected_parts: record.broadcast_part_count)
      add_to_ancestors(result, record, present)
    end
  end

  def add_to_ancestors(result, record, state)
    record.ancestor_ids.each { |id| accumulate(result[id], state) if result.key?(id) }
  end

  def accumulate(values, state)
    values[:total] += 1
    values[:missing] += 1 if state == false
    values[:unknown] += 1 if state.nil?
  end

  def classification(values)
    return 'incomplete' if values[:missing].positive?
    return 'unknown' if values[:total].zero? || values[:unknown].positive?

    'complete'
  end
end
