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

    def call(scope:, gender_ids:, country_ids:)
      candidate = scope.fetch('candidate')
      validate!(candidate, gender_ids, country_ids)
      Record.transaction do
        lock_projects!
        previous = Binding.current(scope.fetch('project').fetch('project_id'))
        next Record.find(previous.fetch('record_id')) if previous

        create_and_bind(scope, candidate, gender_ids, country_ids)
      end
    end

    private

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
      record = existing(candidate) || create_record(candidate, genders, countries)
      result = Identification.new(user: @user, url: @url,
                                  matcher: SelectedFilm.new(record)).call(scope.fetch('project'))
      raise ArgumentError, 'Association à examiner dans la file de consolidation' unless result[:status] == 'identified'

      record
    end

    def existing(candidate)
      title = Record.where('LOWER(french_title) = ?', candidate.fetch('french_title').downcase)
                    .to_a
      source = Record.where("year_evidence ->> 'url' = ?", candidate.fetch('source').fetch('url')).to_a
      matches = (title + source).uniq(&:id)
      return if matches.empty?
      return matches.sole if matches.one? && compatible?(matches.sole, candidate, source)

      raise ArgumentError, "Fiches existantes à examiner avant création : #{matches.map(&:id).join(', ')}"
    end

    def compatible?(record, candidate, sourced)
      same_year = record.year.nil? || candidate['year'].nil? || record.year == candidate['year']
      Matcher.qualified?(record) && (same_year || sourced.include?(record))
    end

    def create_record(candidate, genders, countries)
      record = Record.create!(record_attributes(candidate))
      record.countries = Country.find(countries)
      record.with_reviewed_genre_assignment { record.genders = Gender.find(genders) }
      record.update!(genre_provenance: genre_provenance(candidate, record))
      if candidate['abstract'].present?
        record.save_external_abstract!(candidate['abstract'],
                                       source: candidate.fetch('source'))
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
