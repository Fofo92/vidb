module EncoderProjects
  class EpisodeCatalogue
    attr_reader :warnings

    def initialize(wikipedia: WikipediaClient.new, parser: WikipediaEpisode.new, tmdb: nil, links: CatalogueEpisodeLink)
      @wikipedia = wikipedia
      @parser = parser
      @tmdb = tmdb
      @links = links
      @warnings = []
    end

    def call(series, numbers)
      @warnings = []
      proposals = collect('Wikipédia') { wikipedia_proposals(series, numbers) }
      proposals += collect('TMDB') { tmdb_proposals(series, numbers) }
      proposals.each do |item|
        item.merge!('series_id' => series.id, 'season' => numbers.season, 'episode' => numbers.episode)
      end
      SynopsisPreference.call(proposals.uniq { |item| item.dig('source', 'url') })
    end

    private

    def collect(provider)
      yield
    rescue ArgumentError, KeyError, JSON::ParserError, CatalogEnrichment::TmdbClient::Error,
           IOError, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError
      @warnings << "#{provider} indisponible ou incomplet. Tu peux compléter les champs manquants."
      []
    end

    def wikipedia_proposals(series, numbers)
      names = @wikipedia.search_series(series.french_title.presence || series.original_title)
      names = names.select { |name| compatible_title?(name, series) }.first(2)
      names.flat_map { |name| collect('Wikipédia') { [wikipedia_proposal(name, series, numbers)].compact } }
    end

    def compatible_title?(name, series)
      title = name.sub(/\s*\(.*\)\z/, '').parameterize
      [series.french_title, series.original_title].compact_blank.any? { |value| value.parameterize == title }
    end

    def wikipedia_proposal(name, series, numbers)
      base = name.sub(/\s*\(.*\)\z/, '')
      page = @wikipedia.page("Saison #{numbers.season} de #{base}")
      return unless page.fetch('title').parameterize == "Saison #{numbers.season} de #{base}".parameterize

      proposal = @parser.call(page, numbers.episode)
      return unless proposal

      references = collect('Wikipédia') { [@parser.references(@wikipedia.page(name))] }.first
      references ||= @parser.references(page)
      proposal.merge(reference_ids(series, references))
    end

    def reference_ids(series, candidate)
      { 'gender_ids' => series.effective_genders.map(&:id).presence || proposed_genres(candidate),
        'country_ids' => series.effective_countries.map(&:id).presence || CatalogueReferences.countries(candidate) }
    end

    def proposed_genres(candidate)
      resolved = CatalogueReferences.genres(candidate)
      return resolved if resolved

      text = candidate.fetch('genres_text').downcase
      Gender.all.select { |item| text.include?(item.name.downcase) }
                .sort_by { |item| text.index(item.name.downcase) }.first(2).map(&:id)
    end

    def tmdb_proposals(series, numbers)
      ids = @links.where(provider: 'tmdb', record_id: series.subtree.select(:id))
                  .distinct.limit(3).pluck(:external_series_id)
      ids = searched_series_ids(series) if ids.empty?
      ids.flat_map { |id| collect('TMDB') { [tmdb_proposal(id, series, numbers)].compact } }
    end

    def searched_series_ids(series)
      title = series.french_title.presence || series.original_title
      rows = tmdb.search(title: title).fetch('results').select { |row| matching_series?(series, row) }
      rows.first(3).map { |row| row.fetch('id') }
    end

    def matching_series?(series, row)
      local = SynopsisPreference.normalized_titles([series.french_title, series.original_title])
      remote = SynopsisPreference.normalized_titles(row.values_at('name', 'original_name'))
      return false unless local.intersect?(remote)

      year = row['first_air_date'].to_s[/\A\d{4}/]&.to_i
      series.year.nil? || year.nil? || series.year == year
    end

    def tmdb_proposal(id, series, numbers)
      series_data = tmdb.get("tv/#{id}")
      episode = tmdb.get("tv/#{id}/season/#{numbers.season}").fetch('episodes').find do |row|
        row['episode_number'] == numbers.episode
      end
      episode && tmdb_candidate(id, episode).merge(reference_ids(series, tmdb_references(series_data)))
    end

    def tmdb_candidate(id, episode)
      date = episode['air_date'].to_s
      { 'title' => episode['name'], 'year' => date[/\A\d{4}/]&.to_i, 'abstract' => episode['overview'].to_s,
        'source' => { 'provider' => 'tmdb', 'url' => "https://www.themoviedb.org/tv/#{id}",
                      'first_air_date' => date, 'episode_id' => episode['id'] } }
    end

    def tmdb_references(series_data)
      { 'genres_text' => series_data.fetch('genres', []).map { |item| item['name'] }.join(', '),
        'country_codes' => series_data.fetch('origin_country', []) }
    end

    def tmdb
      @tmdb ||= TmdbSeriesClient.new(cache_dir: Rails.root.join('tmp/catalogue-episodes'))
    end
  end
end
