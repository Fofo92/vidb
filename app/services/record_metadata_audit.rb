# frozen_string_literal: true

# Read-only audit: records and files are deliberately counted separately.
class RecordMetadataAudit
  LABELS = { placement: "Placement", country: "Pays de production", year: "Année",
             genres: "Genres", language: "Version linguistique", abstract: "Résumé", medium: "Support" }.freeze

  def call
    @records = Record.includes(:countries, :genders, :media, :language_version).to_a
    @by_id = @records.index_by(&:id)
    @children = @records.group_by(&:parent_id)
    @assets = VideoAsset.where(status: "present").includes(:medium, :language_version).group_by(&:record_id)
    rows = @records.map { |record| row(record) }
    summary(rows).merge(records: rows.reject { |item| item[:missing].empty? && item[:review].empty? })
  end

  private

  def row(record)
    leaves = leaves_for(record)
    { id: record.id, title: record.complete_title, missing: missing(record, leaves), review: review(record, leaves) }
  end

  def missing(record, leaves)
    missing = []
    missing << :placement unless placement_complete?(record)
    missing << :country unless known_values?(record.countries, :long_name)
    missing << :genres unless known_values?(record.genders, :name)
    missing << :year if leaves.any? { |leaf| leaf.year.blank? }
    missing << :abstract if record.abstract.blank?
    missing.concat(missing_copy_fields(leaves))
  end

  def missing_copy_fields(leaves)
    { language: :language_version, medium: :medium }.filter_map do |field, association|
      field unless leaves.all? { |leaf| qualified?(leaf, association) }
    end
  end

  def leaves_for(record)
    children = @children.fetch(record.id, [])
    children.empty? ? [record] : children.flat_map { |child| leaves_for(child) }
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
    values.any? && values.all? { |value| value && known?(value.short_name) }
  end

  def known_values?(values, attribute)
    values.any? { |value| known?(value.public_send(attribute)) }
  end

  def known?(value)
    value.present? && !%r{\A(?:\?|n/a|inconnue?|unknown|non renseignée?)\z}i.match?(value.strip)
  end

  def review(record, leaves)
    reasons = []
    reasons << "Plus de deux genres" if record.genders.size > 2
    parent = @by_id[record.parent_id]
    if parent && !Record.allowed_parent_kinds_for_hierarchy(record.record_kind).include?(parent.record_kind)
      reasons << "Hiérarchie à vérifier"
    end
    reasons << "Origine de l’année à préciser" if leaves.any? do |leaf|
      leaf.year.present? && leaf.year_basis == "unknown"
    end
    reasons
  end

  def summary(rows)
    incomplete = rows.count { |row| row[:missing].any? }
    review = rows.count { |row| row[:review].any? }
    { generated_at: Time.current.iso8601, total: rows.size, incomplete: incomplete, review: review,
      to_work: rows.count { |row| row[:missing].any? || row[:review].any? },
      missing: LABELS.keys.to_h { |field| [field, rows.count { |row| row[:missing].include?(field) }] } }
  end
end
