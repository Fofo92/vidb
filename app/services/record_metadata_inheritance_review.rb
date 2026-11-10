# frozen_string_literal: true

class RecordMetadataInheritanceReview
  FIELDS = { genders: :name, countries: :long_name }.freeze

  def initialize(records: Record.includes(:genders, :countries).to_a,
                 modes: { genders: 'parent', countries: 'parent' }, include_aligned: false)
    @records = records
    @metadata = RecordMetadataValues.new(records: records)
    @modes = modes
    @include_aligned = include_aligned
  end

  def call
    @records.filter_map { |root| branch(root) if RecordMetadataValues.forcing_root?(root) }
  end

  private

  def branch(root)
    show_aligned = @include_aligned || configured?(root)
    children = branch_children(root)
    return if children.empty? && !show_aligned

    targets = targets_for(root)
    rows = children.filter_map { |record| child_row(record, targets) }
    return if rows.empty? && !show_aligned

    { root: root, targets: targets, children_count: children.size, rows: rows,
      changed_count: rows.count { |row| row[:changed] } }
  end

  def configured?(record)
    RecordMetadataValues::MODE_ATTRIBUTES.values.any? { |attribute| record.public_send(attribute) != 'current' }
  end

  def branch_children(root)
    children = @metadata.children(root)
    return children.select(&:record_kind_standalone_video?) if root.record_kind_collection?

    seasons = children.select(&:record_kind_season?)
    children.select(&:record_kind_episode?) + seasons +
      seasons.flat_map { |season| @metadata.children(season).select(&:record_kind_episode?) }
  end

  def targets_for(root)
    FIELDS.to_h do |field, attribute|
      values = sorted(@metadata.explicit(root, field), attribute)
      ready = RecordMetadataValues.forceable?(field, values)
      configured = root.public_send(RecordMetadataValues::MODE_ATTRIBUTES.fetch(field))
      [field, { values: values, ready: ready, configured: configured }]
    end
  end

  def child_row(record, targets)
    fields = targets.to_h { |field, target| [field, compare_field(record, field, target)] }
    return unless fields.values.any? { |field| field[:review] }

    { record: record, fields: fields, changed: fields.values.any? { |field| field[:changed] } }
  end

  def compare_field(record, field, target)
    attribute = FIELDS.fetch(field)
    own = sorted(@metadata.explicit(record, field), attribute)
    current = sorted(@metadata.public_send(field, record), attribute)
    parent = target.fetch(:values)
    ready = target.fetch(:ready)
    unforced = sorted(@metadata.values_for_mode(record, field, 'current'), attribute)
    proposed = sorted(@metadata.values_for_mode(record, field, @modes.fetch(field)), attribute)
    review = !ready || unforced != parent || proposed != current || (own.any? && own != parent)
    { own: own, current: current, proposed: proposed, changed: proposed != current, review: review }
  end

  def sorted(values, attribute)
    values.uniq(&:id).sort_by { |value| [value.public_send(attribute), value.id] }
  end
end
