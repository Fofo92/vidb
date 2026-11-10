# frozen_string_literal: true

class RecordMetadataInheritanceReview
  FIELDS = { genders: :name, countries: :long_name }.freeze

  def initialize(root:, modes:)
    @root = root
    @metadata = RecordMetadataValues.new(record: root)
    @modes = modes
  end

  def call
    children = branch_children(@root)
    targets = targets_for
    { children_count: children.size, targets: targets, rows: children.filter_map { |record| child_row(record) },
      blocked: targets.values.any? { |target| target[:blocked] }, mode_changed: mode_changed? }
  end

  private

  def branch_children(root)
    children = @metadata.children(root)
    return children.select(&:record_kind_standalone_video?) if root.record_kind_collection?

    seasons = children.select(&:record_kind_season?)
    children.select(&:record_kind_episode?) + seasons +
      seasons.flat_map { |season| @metadata.children(season).select(&:record_kind_episode?) }
  end

  def targets_for
    FIELDS.to_h do |field, attribute|
      values = @metadata.explicit(@root, field).uniq(&:id)
      blocked = @modes.fetch(field) == 'parent' && !RecordMetadataValues.forceable?(field, values)
      [field, { names: names(values, attribute), blocked: blocked }]
    end
  end

  def mode_changed?
    RecordMetadataValues::MODE_ATTRIBUTES.any? do |field, attribute|
      @modes.fetch(field) != @root.public_send(attribute)
    end
  end

  def child_row(record)
    changes = FIELDS.each_with_object({}) do |(field, attribute), result|
      current = @metadata.public_send(field, record)
      proposed = @metadata.values_for_mode(record, field, @modes.fetch(field))
      next if current.map(&:id).sort == proposed.map(&:id).sort

      result[field] = { current: names(current, attribute), proposed: names(proposed, attribute) }
    end
    { record: record, changes: changes } if changes.any?
  end

  def names(values, attribute)
    values.map(&attribute).sort.join(', ')
  end
end
