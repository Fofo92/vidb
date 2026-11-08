class DvdContentSelection
  def call(edition:, rows:)
    edition.with_lock do
      selected = rows.to_h.select { |_id, fields| fields["selected"] == "1" }
      allowed = edition.record.subtree.where(record_kind: %w[episode standalone_video]).pluck(:id).map(&:to_s)
      raise ArgumentError, "Le contenu sélectionné ne fait pas partie de cette œuvre." if (selected.keys - allowed).any?

      selected.each { |id, fields| save_content(edition, id, fields) }
      edition.dvd_contents.where.not(record_id: selected.keys).destroy_all
    end
  end

  private

  def save_content(edition, id, fields)
    content = edition.dvd_contents.find_or_initialize_by(record_id: id)
    content.assign_attributes(fields.slice("language_version_id", "audio_languages", "subtitle_languages"))
    content.save!
  end
end
