# frozen_string_literal: true

module RecordPosters
  class FilmReview
    MESSAGES = {
      invalid_title: 'Renseigne un titre pour rechercher des propositions.',
      partial: 'Recherche partielle : compare les propositions ou indique directement le lien TMDB.',
      empty: 'Aucun résultat trouvé. Essaie un lien TMDB ou une image personnelle.',
      missing_synopsis: 'Le synopsis local manque : confirme la référence après comparaison.',
      multiple: 'Plusieurs références concordent : compare leur présentation avant de choisir.',
      candidate: 'Une proposition concordante est disponible ci-dessous.',
      insufficient: 'Les éléments disponibles ne suffisent pas à choisir automatiquement. ' \
                    'Compare les titres, années et présentations.'
    }.freeze

    def initialize(client: nil)
      client ||= CatalogEnrichment::TmdbFilmClient.new(
        cache_dir: Rails.root.join('tmp/poster-film-cache'), max_age: 6.hours
      )
      @search = CatalogEnrichment::FilmSearchSnapshot.new(client: client)
    end

    def call(record)
      return { message: MESSAGES[:invalid_title], candidates: [] } unless FilmTarget.valid_titles?(record)

      local = record.attributes.slice('french_title', 'original_title', 'abstract', 'year')
      snapshot = @search.call(local: local)
      comparison = FilmPosterComparison.new.call(local: local, results: snapshot.fetch(:results))
      { message: MESSAGES.fetch(reason(local, snapshot, comparison)),
        candidates: candidates(snapshot.fetch(:results), comparison.fetch(:comparisons)) }
    end

    private

    def reason(local, snapshot, comparison)
      return :partial unless snapshot[:complete]
      return :empty if snapshot[:results].empty?
      return :missing_synopsis if local['abstract'].blank?
      return :multiple if comparison[:comparisons].count { |row| row[:supported] } > 1
      return :candidate if comparison[:status] == 'candidate'

      :insufficient
    end

    def candidates(results, comparisons)
      evidence = comparisons.index_by { |row| row[:tmdb_id] }
      results.sort_by { |film| ranking(evidence.fetch(film['id'])) }.first(12).map do |film|
        film.slice('id', 'title', 'original_title', 'release_date', 'overview').symbolize_keys
            .merge(evidence: evidence.fetch(film['id']))
      end
    end

    def ranking(row)
      title = row[:poster_title_matches] || row[:title_matches]
      [row[:supported] ? 0 : 1, title && row[:year_compatible] ? 0 : 1,
       -row[:synopsis_overlap], -row[:shared_synopsis_terms]]
    end
  end
end
