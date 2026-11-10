# frozen_string_literal: true

# These read-only values preserve every explicit association.
class RecordMetadataValues
  REFERENCES = { countries: :long_name, genders: :name }.freeze

  MODE_ATTRIBUTES = { genders: :descendant_genre_mode, countries: :descendant_country_mode }.freeze
  MODES = { 'current' => 'Habituel', 'add' => 'Ajouter le parent', 'parent' => 'Imposer le parent' }.freeze

  def self.forcing_root?(record)
    record&.root? && (record.record_kind_series? || record.record_kind_collection?)
  end

  def self.forceable?(field, values)
    values.any? && (field != :genders || values.size <= 2)
  end

  def initialize(record: nil, records: nil)
    @record = record
    records ||= record.persisted? ? record.root.subtree.includes(:countries, :genders).to_a : [record]
    @by_id = records.index_by(&:id)
    @children = records.group_by(&:parent_id)
  end

  def countries(record = @record)
    effective_values(record, :countries).sort_by(&:long_name)
  end

  def genders(record = @record)
    effective_values(record, :genders).sort_by(&:name)
  end

  def values_for_mode(record, field, mode, root = forcing_root(record))
    return values(record, field) unless root && mode != 'current'

    common = explicit(root, field).uniq(&:id)
    return additive_values(record, field, common) if mode == 'add'
    return common if mode == 'parent' && self.class.forceable?(field, common)

    values(record, field)
  end

  def ancestors(record)
    record.ancestor_ids.reverse.filter_map { |id| @by_id[id] }
  end

  def children(record)
    @children.fetch(record.id, [])
  end

  def self.known?(value)
    value.present? && !%r{\A(?:\?|n/a|inconnue?|unknown|non renseignée?)\z}i.match?(value.strip)
  end

  def explicit(record, association)
    attribute = REFERENCES.fetch(association)
    record.public_send(association).select { |value| self.class.known?(value.public_send(attribute)) }
  end

  private

  def effective_values(record, field)
    root = forcing_root(record)
    mode = root&.public_send(MODE_ATTRIBUTES.fetch(field)) || 'current'
    values_for_mode(record, field, mode, root)
  end

  def additive_values(record, field, common)
    parent = @by_id[record.parent_id]
    seasonal = parent&.record_kind_season? ? explicit(parent, field) : []
    (values(record, field) + seasonal + common).uniq(&:id)
  end

  def forcing_root(record)
    return record if self.class.forcing_root?(record)

    parent = @by_id[record.parent_id]
    case record.record_kind
    when 'standalone_video' then parent if parent&.record_kind_collection? && parent.root?
    when 'season' then parent if parent&.record_kind_series? && parent.root?
    when 'episode' then episode_forcing_root(parent)
    end
  end

  def episode_forcing_root(parent)
    parent = @by_id[parent.parent_id] if parent&.record_kind_season?
    parent if parent&.record_kind_series? && parent.root?
  end

  def values(record, association)
    if record.record_kind_collection?
      return leaves(record).flat_map { |leaf| explicit_or_inherited(leaf, association) }.uniq(&:id)
    end

    inherited = explicit_or_inherited(record, association)
    return inherited if inherited.any? || !record.metadata_container?

    leaves(record).flat_map { |leaf| explicit_or_inherited(leaf, association) }.uniq(&:id)
  end

  def explicit_or_inherited(record, association)
    own = explicit(record, association)
    return own if own.any? || !%w[episode season].include?(record.record_kind)

    ancestors(record).select(&:metadata_container?).each do |parent|
      inherited = explicit(parent, association)
      return inherited if inherited.any?
    end
    []
  end

  def leaves(record)
    descendants = children(record)
    return record.metadata_container? ? [] : [record] if descendants.empty?

    descendants.flat_map { |child| leaves(child) }
  end
end
