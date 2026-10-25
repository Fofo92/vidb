require 'uri'

module EncoderProjects
  class FilmCatalogue
    def initialize(wikipedia: WikipediaClient.new, parser: WikipediaFilm.new, tmdb: nil)
      @wikipedia = wikipedia
      @parser = parser
      @tmdb = tmdb
    end

    def call(query)
      title = query.to_s.strip
      raise ArgumentError, 'Titre ou lien limité à 300 caractères' unless title.present? && title.bytesize <= 300
      return tmdb_id(title) ? [movie(tmdb_id(title))] : [] if title.start_with?('https://www.themoviedb.org/')

      films = wikipedia_films(title)
      films.any? ? films : tmdb_films(title)
    end

    private

    def wikipedia_films(title)
      prefix = 'https://fr.wikipedia.org/wiki/'
      titles = wikipedia_titles(title, prefix)
      titles.filter_map { |name| @parser.call(@wikipedia.page(name)) }.uniq { |film| film.fetch('source').fetch('url') }
    rescue IOError, SystemCallError, Timeout::Error, JSON::ParserError, KeyError, ArgumentError
      []
    end

    def wikipedia_titles(title, prefix)
      return [URI.decode_www_form_component(title.delete_prefix(prefix))] if title.start_with?(prefix)

      titles = @wikipedia.search(title)
      exact = titles.find { |name| name.casecmp?(title) }
      exact ? [exact] : titles
    end

    def tmdb
      @tmdb ||= CatalogEnrichment::TmdbFilmClient.new(cache_dir: Rails.root.join('tmp/encoder-film-search'))
    end

    def tmdb_id(title)
      title[%r{\Ahttps://www\.themoviedb\.org/movie/([1-9]\d*)(?:[-/?].*)?\z}, 1]&.to_i
    end

    def tmdb_films(title)
      tmdb.search(title: title).fetch('results').first(3).map { |entry| movie(entry.fetch('id')) }
    end

    def movie(id)
      data = tmdb.movie(id: id)
      data = CatalogEnrichment::FilmReleaseReference.new.call(movie: data, release_dates: tmdb.release_dates(id: id))
      { 'french_title' => data.fetch('title'), 'original_title' => data['original_title'].to_s,
        'year' => data['release_date']&.first(4)&.to_i,
        'genres_text' => data.fetch('genres', []).pluck('name').join(', '),
        'country_codes' => data.fetch('production_countries', []).map { |item| item['iso_3166_1'] },
        'abstract' => data['overview'].to_s, 'record_kind' => 'standalone_video', 'source' => tmdb_source(data) }
    end

    def tmdb_source(data)
      { 'provider' => 'tmdb', 'tmdb_movie_id' => data.fetch('id'),
        'url' => "https://www.themoviedb.org/movie/#{data.fetch('id')}",
        'release_reference' => data.fetch('_vidb_release_evidence'), 'observed_at' => Time.current.iso8601 }
    end
  end
end
