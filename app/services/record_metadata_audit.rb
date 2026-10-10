# frozen_string_literal: true

class RecordMetadataAudit
  LABELS = { placement: "Placement", country: "Pays de production", year: "Année",
             genres: "Genres", language: "Version linguistique", abstract: "Résumé", medium: "Support" }.freeze
  GROUP_LABELS = { videos: 'Films et épisodes', series: 'Séries', seasons: 'Saisons',
                   undetermined: 'Fiches à qualifier' }.freeze

  def call
    records = Record.includes(:countries, :genders, :media, :language_version).to_a
    assets = VideoAsset.where(status: "present").includes(:medium, :language_version).group_by(&:record_id)
    operation = RecordMetadataAuditRow.new(records: records, assets: assets)
    rows = records.map { |record| operation.call(record) }
    groups = GROUP_LABELS.keys.to_h { |key| [key, summary(rows.select { |row| group(row) == key })] }
    summary(rows).merge(groups: groups, records: rows.reject { |row| row[:missing].empty? && row[:review].empty? })
  end

  private

  def group(row)
    return :series if row[:record_kind] == 'series'
    return :seasons if row[:record_kind] == 'season'
    return :undetermined if row[:record_kind] == 'undetermined'

    :videos
  end

  def summary(rows)
    { generated_at: Time.current.iso8601, total: rows.size,
      incomplete: rows.count { |row| row[:missing].any? }, review: rows.count { |row| row[:review].any? },
      to_work: rows.count { |row| row[:missing].any? || row[:review].any? },
      missing: LABELS.keys.to_h { |field| [field, rows.count { |row| row[:missing].include?(field) }] } }
  end
end
