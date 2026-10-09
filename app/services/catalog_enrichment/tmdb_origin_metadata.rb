# frozen_string_literal: true

module CatalogEnrichment
  # Country of origin is distinct from production partners; genre selection is explicit.
  class TmdbOriginMetadata
    def initialize(evidence:, snapshot:, records:)
      @evidence = evidence
      @snapshot = snapshot
      @records = records
      validate_source!
    end

    def plan
      metadata.plan
    end

    def apply!
      metadata.apply!
    end

    def labels
      { countries: country_names, genre_candidates: @evidence.fetch('genre_dictionary_names'),
        basis: @evidence.fetch('genre_basis') }
    end

    private

    def validate_source!
      valid = @snapshot['format'] == 'vidb.tmdb_series_snapshot' &&
              @snapshot['tmdb_series_id'] == @evidence.fetch('tmdb_series_id') &&
              @snapshot.fetch('series').fetch('origin_country').sort == @evidence.fetch('origin_country_codes').sort
      raise ArgumentError, 'TMDB country-of-origin evidence changed' unless valid

      ids = @snapshot.fetch('series').fetch('genres').pluck('id')
      expected = @evidence.fetch('expected_tmdb_genre_id', 80)
      raise ArgumentError, 'Selected TMDB genre missing' unless ids.include?(expected)
    end

    def country_names
      countries = Country.where(long_name: @evidence.fetch('country_dictionary_names')).to_a
      raise ArgumentError, 'Missing or ambiguous country dictionary entry' unless countries.one?

      countries.map(&:long_name)
    end

    def metadata
      ConfirmedMetadata.new(records: @records, episodes: [], countries: country_names,
                            genres: @evidence.fetch('genre_dictionary_names'), year: nil)
    end
  end
end
