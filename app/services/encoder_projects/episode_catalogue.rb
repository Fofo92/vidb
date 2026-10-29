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

    def call(series, numbers, tmdb_series_id: nil, tmdb_episode: nil)
      @warnings = []
      @numbering_page = nil
      select_tmdb_source(tmdb_series_id, tmdb_episode)
      proposals = collect('Wikipédia') { wikipedia_proposals(series, numbers) }
      proposals += collect('TMDB') { tmdb_proposals(series, numbers) }
      proposals.each do |item|
        item.merge!('series_id' => series.id, 'season' => numbers.season, 'episode' => numbers.episode)
      end
      distinct = proposals.uniq { |item| item.dig('source', 'url') }
      CatalogueCompletionProposal.call(SynopsisPreference.call(EpisodeTitles.enrich(distinct)))
    end

    private

    def select_tmdb_source(id, episode)
      @explicit_tmdb_id = id
      @explicit_episode = episode
    end

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
      lookup = WikipediaEpisodeLookup.new(wikipedia: @wikipedia, parser: @parser)
      proposal, references = lookup.call(name, numbers.season, numbers.episode)
      @numbering_page = lookup.main_page if proposal&.dig('source', 'numbering_basis') == 'season_ordered_list'
      proposal&.merge(reference_ids(series, references))
    end

    def reference_ids(series, candidate)
      { 'gender_ids' => series.effective_genders.map(&:id).presence || proposed_genres(candidate),
        'country_ids' => series.effective_countries.map(&:id).presence || CatalogueReferences.countries(candidate) }
    end

    def proposed_genres(candidate)
      resolved = CatalogueReferences.genres(candidate)
      return resolved if resolved

      text = candidate.fetch('genres_text').downcase
      matches = Gender.all.select { |item| text.include?(item.name.downcase) }
      matches.sort_by { |item| text.index(item.name.downcase) }.first(2).map(&:id)
    end

    def tmdb_proposals(series, numbers)
      ids = explicit_or_stored_ids(series)
      ids = searched_series_ids(series) if ids.empty?
      ids.flat_map { |id| collect('TMDB') { [tmdb_proposal(id, series, numbers)].compact } }
    end

    def explicit_or_stored_ids(series)
      return [@explicit_tmdb_id] if @explicit_tmdb_id

      @links.where(provider: 'tmdb', record_id: series.subtree.select(:id))
            .distinct.limit(3).pluck(:external_series_id)
    end

    def searched_series_ids(series)
      rows = tmdb.search(title: series.french_title.presence || series.original_title).fetch('results')
      rows.select { |row| matching_series?(series, row) }.first(3).map { |row| row.fetch('id') }
    end

    def matching_series?(series, row)
      local = SynopsisPreference.normalized_titles([series.french_title, series.original_title])
      remote = SynopsisPreference.normalized_titles(row.values_at('name', 'original_name'))
      return false unless local.intersect?(remote)

      year = row['first_air_date'].to_s[/\A\d{4}/]&.to_i
      series.year.nil? || year.nil? || series.year == year
    end

    def tmdb_proposal(id, series, numbers)
      lookup = TmdbEpisodeLookup.new(client: tmdb, page: @numbering_page, links: @links, warnings: @warnings)
      lookup.call(id, series, numbers, reference: @explicit_episode) do |proposal, data|
        proposal.merge(reference_ids(series, tmdb_references(data)))
      end
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
