module EncoderProjects
  # Completes only the film already associated with the project.
  class ExistingFilmCompletion
    def self.bound_record!(project)
      binding = Binding.current(project.fetch('project_id'))
      record_id = project.fetch('completion_record_id')
      raise ArgumentError, 'La fiche associée a changé ; reprends l’identification du montage.' unless
        binding && binding['record_id'] == record_id

      record = Record.find(record_id)
      raise ArgumentError, 'La fiche associée n’est plus un film.' unless record.record_kind_standalone_video?

      record
    end

    def initialize(user:)
      @user = user
    end

    def call(project, candidate, gender_ids, country_ids)
      record = self.class.bound_record!(project)
      record.with_lock do
        verify_candidate!(record, candidate)
        fill_identity(record, candidate)
        fill_genres(record, candidate, gender_ids)
        record.countries = Country.find(country_ids) if country_ids.any? && record.effective_countries.empty?
        CatalogueSummaryImport.call(record, candidate) if record.abstract.blank?
      end
      record
    end

    private

    def verify_candidate!(record, candidate)
      return if record.year.blank? || candidate['year'].blank? || record.year == candidate['year']

      raise ArgumentError, 'L’année proposée diffère de celle de la fiche associée. Vérifie la source choisie.'
    end

    def fill_identity(record, candidate)
      if record.year.blank? && candidate['year'].present?
        record.assign_attributes(year: candidate['year'], year_basis: 'first_release',
                                 year_evidence: candidate.fetch('source'))
      end
      title = candidate['original_title']
      record.original_title = title if record.original_title.blank? && title.present? && title != record.french_title
      record.save! if record.changed?
    end

    def fill_genres(record, candidate, ids)
      return if ids.empty? || record.effective_genders.any? || record.genre_provenance.to_h['protected']

      genres = Gender.find(ids)
      record.with_reviewed_genre_assignment { record.genders = genres }
      provenance = {
        'origin' => 'reviewed_encoder_catalogue', 'protected' => true, 'user_id' => @user.id,
        'genres' => genres.map(&:name), 'source' => candidate.fetch('source'), 'recorded_at' => Time.current.iso8601
      }
      record.update!(genre_provenance: provenance)
    end
  end
end
