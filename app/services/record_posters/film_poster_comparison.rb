# frozen_string_literal: true

require 'date'

module RecordPosters
  # Additional corroboration is confined to artwork; catalogue identity rules stay unchanged.
  class FilmPosterComparison
    NUMBERS = %w[zero un deux trois quatre cinq six sept huit neuf dix onze douze treize quatorze quinze seize]
              .each_with_index.to_h.freeze
    ROMANS = %w[i ii iii iv v vi vii viii ix x xi xii xiii xiv xv xvi xvii xviii xix xx]
             .each_with_index.to_h { |word, index| [word, index + 1] }.freeze
    STOP_WORDS = CatalogEnrichment::FilmIdentityComparison::STOP_WORDS

    def initialize(comparison: CatalogEnrichment::FilmIdentityComparison.new)
      @comparison = comparison
    end

    def call(local:, results:)
      base = @comparison.call(local: local, results: results)
      films = results.index_by { |film| film.fetch('id') }
      rows = base.fetch(:comparisons).map { |row| corroborate(local, films.fetch(row[:tmdb_id]), row) }
      accepted = rows.select { |row| row[:supported] }
      base.merge(status: accepted.one? ? 'candidate' : 'needs_review', comparisons: rows,
                 tmdb_id: accepted.one? ? accepted.first[:tmdb_id] : nil,
                 reason: accepted.one? ? 'Titre, chronologie et contenu concordants pour la pochette.' : base[:reason])
    end

    private

    def corroborate(local, film, row)
      matched = titles(local, %w[french_title original_title]) & titles(film, %w[title original_title])
      terms = matched.map { |title| distinctive_terms(title).size }.max || 0
      chronology = chronology_matches?(local['year'], film['release_date'], terms)
      context = matched.any? && terms >= 2 && chronology && supporting_content?(local, film, row)
      row.merge(supported: row[:supported] || context, poster_corroborated: context,
                poster_title_matches: matched.any?, poster_chronology_matches: chronology)
    end

    def supporting_content?(local, film, row)
      original_title_compatible?(local, film) && row[:shared_synopsis_terms] >= 4 && row[:synopsis_overlap] >= 0.15
    end

    def titles(item, fields)
      item.values_at(*fields).map { |text| normalize(text) }.reject(&:empty?).uniq
    end

    def normalize(text)
      words = text.to_s.unicode_normalize(:nfkd).gsub(/\p{Mn}/, '').downcase.gsub(/[^\p{Alnum}]+/, ' ').split
      words.map { |word| NUMBERS.fetch(word, ROMANS.fetch(word, word)).to_s }.join(' ')
    end

    def distinctive_terms(title)
      title.split.reject { |word| word.size < 3 || STOP_WORDS.include?(word) }.uniq
    end

    def original_title_compatible?(local, film)
      original = normalize(local['original_title'])
      original.empty? || original == normalize(local['french_title']) ||
        titles(film, %w[title original_title]).include?(original)
    end

    def chronology_matches?(local_year, release_date, terms)
      return false unless local_year.is_a?(Integer)

      difference = (local_year - Date.iso8601(release_date.to_s).year).abs
      difference.zero? || (terms >= 5 && difference <= 1)
    rescue Date::Error
      false
    end
  end
end
