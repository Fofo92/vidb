# frozen_string_literal: true

require 'date'

module CatalogEnrichment
  # Field proposals only: never saves a Record or rewrites editorial content.
  class FilmMetadataProposal
    GENRES = { 28 => 'Action', 12 => 'Aventure', 16 => 'Animation', 35 => 'Comédie', 80 => 'Policier',
               18 => 'Drame', 14 => 'Fantastique', 36 => 'Histoire', 27 => 'Horreur', 10_402 => 'Musique',
               10_749 => 'Romance', 878 => 'Science fiction', 53 => 'Thriller', 10_752 => 'Guerre',
               37 => 'Western' }.freeze

    def call(local:, movie:, known_genres:)
      { record_id: local.fetch('record_id'), tmdb_id: movie.fetch('id'),
        source: { provider: 'tmdb', external_id: movie.fetch('id'),
                  url: "https://www.themoviedb.org/movie/#{movie.fetch('id')}" },
        year: year_proposal(local, movie), genres: genre_proposal(local, movie, known_genres),
        abstract: { status: 'preserved', reason: 'Aucun résumé n’est réécrit par cet incrément.' },
        source_release_date: movie['release_date'], execution_authorized: false }
    end

    private

    def year_proposal(local, movie)
      date = parse_date(movie['release_date'])
      unless credible_date?(date, local['year'])
        return { status: 'needs_review', reason: 'Date absente, invalide, future ou écart chronologique important.' }
      end

      protected = local.fetch('year_basis') != 'unknown' || local.fetch('year_evidence', {}).present?
      { status: protected ? 'protected' : 'candidate', current: local['year'], proposed: date.year,
        year_basis: 'first_release', date: date.iso8601,
        changed_value: local['year'] != date.year, reference: movie['_vidb_release_evidence'],
        reason: protected ? 'Provenance existante conservée.' : 'Date release_date du catalogue externe, à qualifier.' }
    end

    def credible_date?(date, year)
      return false unless date && date.year >= 1900 && date <= Date.current

      year.nil? || (year - date.year).abs <= 2
    end

    def genre_proposal(local, movie, known)
      external = movie.fetch('genres', [])
      resolved = resolve_genres(external, known)
      existing = local.fetch('genres')
      { status: genre_status(existing, resolved), current: existing, proposed: resolved,
        external_genres: external, reason: genre_reason(existing, !resolved.nil?), maximum_genres: 2 }
    end

    def resolve_genres(genres, known)
      ids = genres.map { |genre| genre['id'] }.uniq
      return unless ids.size.between?(1, 2) && ids.all? { |id| GENRES.key?(id) }

      names = ids.map { |id| GENRES.fetch(id) }
      resolved = names.filter_map { |name| known_genre(name, known) }.uniq.sort
      resolved if resolved.size == names.size
    end

    def known_genre(name, known)
      known.find { |entry| entry.casecmp?(name) }
    end

    def genre_status(existing, resolved)
      return resolved ? 'candidate' : 'needs_review' if existing.empty?

      existing.sort == resolved ? 'consistent' : 'protected'
    end

    def genre_reason(existing, acceptable)
      return 'Classement renseigné conservé ; aucune correction implicite par une source externe.' if existing.any?
      return 'Un ou deux genres externes correspondent au référentiel local.' if acceptable

      'Genres trop nombreux, absents, hors référentiel ou nécessitant une qualification spécifique.'
    end

    def parse_date(value)
      return unless value.is_a?(String) && value.match?(/\A\d{4}-\d{2}-\d{2}\z/)

      Date.iso8601(value)
    rescue Date::Error
      nil
    end
  end
end
