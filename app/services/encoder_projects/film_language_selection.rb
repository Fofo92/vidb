module EncoderProjects
  class FilmLanguageSelection
    def self.call(version_id, project:, &)
      return preserve_choice(project, &) if version_id.blank?

      version = LanguageVersion.find(version_id)
      Record.transaction do
        record = yield
        raise ArgumentError, 'Le choix de version concerne une fiche film.' unless record.record_kind_standalone_video?

        record.update!(language_version: version)
        store_choice(project, record, version)
        record
      end
    end

    def self.preserve_choice(project)
      Record.transaction do
        previous = Binding.current_case(project.fetch('project_id'))&.result
        record = yield
        keep_choice(project, record, previous) if previous&.key?('selected_film_version')
        record
      end
    end

    def self.keep_choice(project, record, previous)
      return unless previous['record_id'] == record.id

      version = record.reload.language_version
      store_choice(project, record, version) if previous['selected_film_version'] == version.short_name
    end

    def self.store_choice(project, record, version)
      item = Binding.current_case(project.fetch('project_id'))
      raise ArgumentError, 'Aucune liaison active pour enregistrer la version du montage.' unless item

      item.with_lock do
        unless item.result['record_id'] == record.id
          raise ArgumentError, 'La fiche liée au montage a changé. Reprends la sélection.'
        end

        item.update!(result: item.result.merge('selected_film_version' => version.short_name))
      end
    end
  end
end
