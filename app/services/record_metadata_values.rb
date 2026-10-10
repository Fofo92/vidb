# frozen_string_literal: true

# These read-only values preserve every explicit association.
class RecordMetadataValues
  REFERENCES = { countries: :long_name, genders: :name }.freeze

  def initialize(record: nil, records: nil)
    @record = record
    records ||= record.persisted? ? record.root.subtree.includes(:countries, :genders).to_a : [record]
    @by_id = records.index_by(&:id)
    @children = records.group_by(&:parent_id)
  end

  def countries(record = @record)
    values(record, :countries).sort_by(&:long_name)
  end

  def genders(record = @record)
    values(record, :genders).sort_by(&:name)
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

  def values(record, association)
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
