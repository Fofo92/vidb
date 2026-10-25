module EncoderProjects
  class SeriesCreation
    def initialize(candidate)
      @candidate = candidate
    end

    def call
      validate!
      matches = matching_roots
      raise ArgumentError, "Plusieurs fiches de série à examiner : #{matches.map(&:id).join(', ')}" if matches.many?
      return checked_root(matches.sole) if matches.one?

      Record.create!(@candidate.slice('french_title', 'original_title', 'year').merge(
                       record_kind: 'series', language_version: LanguageVersion.where(short_name: 'IND').sole,
                       year_basis: @candidate['year'] ? 'first_release' : 'unknown',
                       year_evidence: @candidate.fetch('source'),
                       is_recorded: false, is_available: false, is_seen: false
                     ))
    end

    private

    def validate!
      valid = @candidate['tmdb_id'].is_a?(Integer) && @candidate['tmdb_id'].positive? &&
              @candidate['french_title'].to_s.strip.length.between?(1, 300)
      raise ArgumentError, 'Identité externe de série requise' unless valid
    end

    def matching_roots
      names = title_keys(@candidate.values_at('french_title', 'original_title'))
      Record.where(ancestry: nil).select do |record|
        year = record.year.nil? || @candidate['year'].nil? || record.year == @candidate['year']
        year && title_keys(record.attributes.values_at('french_title', 'original_title')).intersect?(names)
      end
    end

    def title_keys(names)
      names.compact_blank.map { |name| name.parameterize.presence || name.unicode_normalize.downcase.squish }
    end

    def verify_catalogue_identity!(record)
      ids = CatalogueEpisodeLink.where(provider: 'tmdb', record_id: record.subtree.select(:id))
                                .distinct.pluck(:external_series_id)
      return if ids.empty? || ids == [@candidate.fetch('tmdb_id')]

      raise ArgumentError, "La fiche #{record.id} possède déjà une autre identité de série TMDB."
    end

    def checked_root(record)
      record.lock!
      unless record.record_kind_series?
        raise ArgumentError, "La fiche #{record.id} doit être qualifiée comme série avant la création des enfants."
      end

      verify_catalogue_identity!(record)
      record
    end
  end
end
