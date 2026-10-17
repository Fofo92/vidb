# frozen_string_literal: true

require 'date'

module CatalogEnrichment
  # First public presentation/release, not a later local theatrical or disc date.
  class FilmReleaseReference
    PUBLIC_TYPES = [1, 2, 3, 4, 6].freeze

    def call(movie:, release_dates:)
      raise ArgumentError, 'Release dates belong to another film' unless movie.fetch('id') == release_dates.fetch('id')

      entries = release_dates.fetch('results').flat_map { |country| public_dates(country) }
      first = entries.min_by { |entry| entry[:date] }
      evidence = reference_evidence(movie, entries, first)
      movie.merge('release_date' => first&.fetch(:date), '_vidb_release_evidence' => evidence)
    end

    private

    def public_dates(country)
      country.fetch('release_dates').filter_map do |release|
        next unless PUBLIC_TYPES.include?(release['type'])

        date = valid_date(release['release_date'])
        { country: country.fetch('iso_3166_1'), type: release['type'], date: date.iso8601 } if date
      end
    end

    def valid_date(value)
      return unless value.is_a?(String) && value.match?(/\A\d{4}-\d{2}-\d{2}(?:T.*)?\z/)

      date = Date.iso8601(value[0, 10])
      date if date.year >= 1900 && date <= Date.current
    rescue Date::Error
      nil
    end

    def reference_evidence(movie, entries, first)
      { provider: 'tmdb', endpoint: "movie/#{movie.fetch('id')}/release_dates",
        policy: 'first_public_release_v1', primary_release_date: movie['release_date'],
        public_types: PUBLIC_TYPES, selected: first,
        same_first_date: first ? entries.select { |entry| entry[:date] == first[:date] }.uniq : [],
        observed_release_years: entries.map { |entry| entry[:date][0, 4].to_i }.uniq.sort,
        qualification: 'Première présentation ou sortie publique répertoriée ; édition physique exclue.' }
    end
  end
end
