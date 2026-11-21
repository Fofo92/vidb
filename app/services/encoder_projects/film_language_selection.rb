module EncoderProjects
  class FilmLanguageSelection
    def self.call(version_id, project:)
      return yield if version_id.blank?

      version = LanguageVersion.find(version_id)
      Record.transaction do
        record = yield
        raise ArgumentError, 'Le choix de version concerne une fiche film.' unless record.record_kind_standalone_video?

        record.update!(language_version: version)
        store_choice(project, record, version)
        record
      end
    end

    def self.store_choice(project, record, version)
      item = Binding.current_case(project.fetch('project_id'))
      return unless item

      item.with_lock do
        next unless item.result['record_id'] == record.id

        item.update!(result: item.result.merge('selected_film_version' => version.short_name))
      end
    end
  end
end
