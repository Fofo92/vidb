# frozen_string_literal: true

class RecordMetadataAuditRow
  def initialize(records:, assets:)
    @values = RecordMetadataValues.new(records: records)
    @by_id = records.index_by(&:id)
    @assets = assets
  end

  def call(record)
    { id: record.id, title: record.complete_title, record_kind: record.record_kind,
      missing: missing(record), review: review(record) }
  end

  private

  def missing(record)
    fields = []
    fields << :placement unless placement_complete?(record)
    fields.concat(missing_references(record))
    fields << :year if !record.metadata_container? && record.year.blank?
    fields << :abstract if record.record_kind != 'season' && record.abstract.blank?
    fields.concat(missing_copy_fields(record)) unless record.metadata_container?
    fields
  end

  def missing_references(record)
    return [] if record.record_kind_season?

    { country: :countries, genres: :genders }.filter_map do |field, association|
      field if missing_reference?(record, association)
    end
  end

  def missing_reference?(record, association)
    return false if @values.explicit(record, association).any?
    return true if record.record_kind_series?
    return false if record.record_kind == 'episode' && @values.ancestors(record).any?(&:record_kind_series?)

    @values.public_send(association, record).empty?
  end

  def missing_copy_fields(record)
    { language: :language_version, medium: :medium }.filter_map do |field, association|
      field unless qualified?(record, association)
    end
  end

  def placement_complete?(record)
    return false if record.record_kind == "undetermined"

    parent = @by_id[record.parent_id]
    return %w[standalone_video series].include?(record.record_kind) unless parent

    parent.record_kind != "undetermined" &&
      Record.allowed_parent_kinds_for_hierarchy(record.record_kind).include?(parent.record_kind)
  end

  def qualified?(record, association)
    copies = @assets.fetch(record.id, [])
    values = if copies.empty?
               association == :medium ? record.media : [record.language_version].compact
             else
               copies.map { |copy| copy.public_send(association) }
             end
    values.any? && values.all? { |value| value && RecordMetadataValues.known?(value.short_name) }
  end

  def review(record)
    reasons = []
    reasons << "Plus de deux genres" if record.genders.size > 2
    reasons << "Hiérarchie à vérifier" if incompatible_parent?(record)
    if !record.metadata_container? && record.year.present? && record.year_basis == "unknown"
      reasons << "Origine de l’année à préciser"
    end
    reasons << "Ensemble sans enfant" if record.metadata_container? && @values.children(record).empty?
    reasons
  end

  def incompatible_parent?(record)
    parent = @by_id[record.parent_id]
    parent && !Record.allowed_parent_kinds_for_hierarchy(record.record_kind).include?(parent.record_kind)
  end
end
