module ReconciliationWorkbench
  module SeriesCreation
    def self.preview(group)
      data = group.fetch('proposed_new_root')
      attributes = data.slice('french_title', 'original_title')
      title = attributes.fetch('french_title')
      source_name = group.fetch('reference_show').fetch('name')
      names = attributes.values.compact_blank.flat_map { |name| SeriesTitles.keys(name) }
      valid = title.is_a?(String) && title.present? && names.include?(SeriesTitles.key(source_name))
      raise ArgumentError, 'Identité de série documentée requise' unless valid

      SeriesEvidence.source!(group.fetch('reference_url'))
      Record.new(attributes.merge('record_kind' => 'series'))
    end

    def self.conflicts(root, index)
      [root.french_title, root.original_title].compact_blank.flat_map do |title|
        SeriesTitles.candidates(index, title)
      end.uniq.sort
    end

    def self.call(payload)
      root = Record.new(payload.fetch('new_root').slice('french_title', 'original_title'))
      raise ArgumentError, 'Une identité concurrente empêche la création de la série' if
        conflicts(root, SeriesTitles.index).any?
      raise ArgumentError, 'Création de série sans épisodes concordants' if payload.fetch('operations').empty?

      language = unknown_language
      root.assign_attributes(record_kind: 'series', language_version: language)
      root.save!
      result = SeriesStructureAction.new.call(payload.merge('record_id' => root.id,
                                                            'language_version_id' => language.id))
      result.merge('root_id' => root.id)
    end

    def self.unknown_language
      language = LanguageVersion.find_or_create_by!(short_name: 'IND') { |item| item.long_name = 'Indéterminée' }
      raise ArgumentError, 'Code de langue IND déjà employé autrement' unless language.long_name == 'Indéterminée'

      language
    end
  end
end
