module EncoderProjects
  class FilmLanguageSelection
    def self.call(version_id)
      return yield if version_id.blank?

      version = LanguageVersion.find(version_id)
      Record.transaction do
        record = yield
        raise ArgumentError, 'Le choix de version concerne une fiche film.' unless record.record_kind_standalone_video?

        record.update!(language_version: version)
        record
      end
    end
  end
end
