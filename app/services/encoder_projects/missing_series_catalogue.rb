module EncoderProjects
  class MissingSeriesCatalogue
    attr_reader :warnings

    def initialize(tmdb: nil, wikipedia: WikipediaClient.new, references: CatalogueReferences)
      @tmdb = tmdb
      @wikipedia = wikipedia
      @references = references
      @warnings = []
    end

    def call(query, numbers)
      @warnings = []
      rows = tmdb.search(title: query).fetch('results').first(3)
      rows.flat_map { |row| proposals(row.fetch('id'), numbers) }
    rescue ArgumentError, KeyError, CatalogEnrichment::TmdbClient::Error
      @warnings << 'Catalogue de séries indisponible ou incomplet : aucune fiche créée.'
      []
    end

    private

    def proposals(id, numbers)
      data = fetch_series_data(id)
      preview = SeriesPreview.new(data)
      catalogue = EpisodeCatalogue.new(wikipedia: @wikipedia, tmdb: tmdb, links: SeriesPreview::Links.new(id))
      rows = catalogue.call(preview, numbers)
      @warnings.concat(catalogue.warnings)
      @warnings << "Épisode demandé non trouvé pour #{data.fetch('french_title')}." if rows.empty?
      rows.map { |row| row.merge('series_candidate' => data) }
    rescue ArgumentError, KeyError, CatalogEnrichment::TmdbClient::Error
      @warnings << "Série TMDB #{id} indisponible ou incomplète."
      []
    end

    def fetch_series_data(id)
      row = tmdb.get("tv/#{id}")
      raise ArgumentError, 'Identité de série différente' unless row.fetch('id') == id

      series_data(row)
    end

    def series_data(row)
      references = { 'genres_text' => row.fetch('genres', []).pluck('name').join(', '),
                     'country_codes' => row.fetch('origin_country', []) }
      { 'tmdb_id' => row.fetch('id'), 'french_title' => row.fetch('name'),
        'original_title' => row['original_name'].to_s, 'year' => row['first_air_date'].to_s[/\A\d{4}/]&.to_i,
        'source' => { 'provider' => 'tmdb', 'url' => "https://www.themoviedb.org/tv/#{row.fetch('id')}" },
        'gender_ids' => @references.genres(references) || [], 'country_ids' => @references.countries(references),
        'episode_count' => row.fetch('seasons', []).sum { |season| season['episode_count'].to_i },
        'season_count' => row.fetch('seasons', []).size }
    end

    def tmdb
      @tmdb ||= TmdbSeriesClient.new(cache_dir: Rails.root.join('tmp/catalogue-episodes'))
    end
  end
end
