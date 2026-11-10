module EncoderProjects
  class CatalogueCreation
    SelectedFilm = Struct.new(:record) do
      def call(_request)
        { status: 'exact', candidates: [{ record_id: record.id, record_kind: 'standalone_video' }] }
      end
    end

    def initialize(user:, url:)
      @user = user
      @url = url
    end

    def call(scope:, gender_ids:, country_ids:, confirmed: false)
      candidate = scope.fetch('candidate')
      validate!(candidate, gender_ids, country_ids)
      project = scope.fetch('project')
      Record.transaction do
        lock_projects!
        if project['completion_record_id']
          next ExistingFilmCompletion.new(user: @user).call(project, candidate, gender_ids, country_ids)
        end

        associate(scope, candidate, gender_ids, country_ids, confirmed: confirmed)
      end
    end

    private

    def associate(scope, candidate, gender_ids, country_ids, confirmed:)
      project = scope.fetch('project')
      AssociationRevision.call(project, confirmed: confirmed) do
        previous = Binding.current(project.fetch('project_id'))
        next complete_record(Record.find(previous.fetch('record_id')), candidate) if previous

        create_and_bind(scope, candidate, gender_ids, country_ids)
      end
    end

    def lock_projects!
      Record.connection.execute('SELECT pg_advisory_xact_lock(20261024, 2)') if
        Record.connection.adapter_name == 'PostgreSQL'
    end

    def validate!(candidate, genres, countries)
      raise ArgumentError, 'Proposition de film absente' unless candidate.is_a?(Hash) &&
                                                                candidate['record_kind'] == 'standalone_video'
      raise ArgumentError, 'Choisis au maximum deux genres' unless genres.uniq.size <= 2
      raise ArgumentError, 'Trop de pays sélectionnés' if countries.uniq.size > 10

      Gender.find(genres)
      Country.find(countries)
    end

    def create_and_bind(scope, candidate, genders, countries)
      project = scope.fetch('project')
      record = existing(candidate, project) || create_record(candidate, genders, countries)
      complete_record(record, candidate)
      result = Identification.new(user: @user, url: @url,
                                  matcher: SelectedFilm.new(record)).call(project)
      raise ArgumentError, 'Association à examiner dans la file de consolidation' unless result[:status] == 'identified'

      record
    end

    def complete_record(record, candidate)
      CatalogueRuntime.import(record, candidate)
      completed = CatalogueSummaryImport.call(record, candidate)
      PosterIdentityImport.call(record, candidate)
      completed
    end

    def existing(candidate, project = {})
      title = Record.where('LOWER(french_title) = ?', candidate.fetch('french_title').downcase)
                    .to_a
      source = Record.where("year_evidence ->> 'url' = ?", candidate.fetch('source').fetch('url')).to_a
      title.reject! { |record| distinct_work?(record, candidate, project) && !source.include?(record) }
      matches = (title + source).uniq(&:id)
      return if matches.empty?
      return matches.sole if matches.one? && compatible?(matches.sole, candidate, source)

      raise ArgumentError, "Fiches existantes à examiner avant création : #{matches.map(&:id).join(', ')}"
    end

    def compatible?(record, candidate, sourced)
      same_year = record.year.nil? || candidate['year'].nil? || record.year == candidate['year']
      record.record_kind_standalone_video? && Matcher.qualified?(record) && (same_year || sourced.include?(record))
    end

    def distinct_work?(record, candidate, project)
      return false if record.year.blank? || candidate['year'].blank? || record.year == candidate['year']
      return true if record.has_parent?

      record.record_kind_standalone_video? && explicit_tmdb_revision?(candidate, project)
    end

    def explicit_tmdb_revision?(candidate, project)
      url = project['explicit_tmdb_movie_url']
      project['replace_binding'].present? && url.present? &&
        candidate.dig('source', 'provider') == 'tmdb' && candidate.dig('source', 'url') == url
    end

    def create_record(candidate, genders, countries)
      record = Record.create!(record_attributes(candidate))
      record.countries = Country.find(countries)
      record.with_reviewed_genre_assignment { record.genders = Gender.find(genders) }
      record.update!(genre_provenance: genre_provenance(candidate, record))
      if candidate['abstract'].present?
        record.save_external_abstract!(candidate['abstract'],
                                       source: candidate['abstract_source'] || candidate.fetch('source'))
      end
      record
    end

    def record_attributes(candidate)
      titles = candidate.slice('french_title', 'original_title')
      titles['original_title'] = '' if titles['original_title'] == titles['french_title']
      titles.merge('record_kind' => 'standalone_video', 'year' => candidate['year'],
                   'year_basis' => candidate['year'] ? 'first_release' : 'unknown',
                   'year_evidence' => candidate.fetch('source'),
                   'language_version' => LanguageVersion.where(short_name: 'IND').sole,
                   'is_recorded' => false, 'is_available' => false, 'is_seen' => false)
    end

    def genre_provenance(candidate, record)
      { 'origin' => 'reviewed_encoder_catalogue', 'protected' => true, 'user_id' => @user.id,
        'genres' => record.genders.map(&:name), 'source' => candidate.fetch('source'),
        'recorded_at' => Time.current.iso8601 }
    end
  end
end
