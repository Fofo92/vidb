module EncoderProjects
  class TmdbEpisodeProposal
    attr_reader :series_data

    def initialize(client:, wikipedia_page:, links:, warnings:)
      @client = client
      @page = wikipedia_page
      @links = links
      @warnings = warnings
    end

    def call(id, series, numbers)
      @series_data = @client.get("tv/#{id}")
      season = @client.get("tv/#{id}/season/#{numbers.season}")
      entries = @page ? WikipediaSeasonEpisode.new.entries(@page, numbers.season) : {}
      @stored_edition = StoredEpisodeEdition.new(local_links(series))
      return raw_proposal(id, season, numbers) if entries.empty? && !@stored_edition.mapped?

      mapped_proposal(id, season, series, entries, numbers)
    end

    private

    def raw_proposal(id, season, numbers)
      episode = season.fetch('episodes').find { |row| row['episode_number'] == numbers.episode }
      return unless episode

      source = { 'provider' => 'tmdb', 'url' => "https://www.themoviedb.org/tv/#{id}",
                 'first_air_date' => episode['air_date'].to_s, 'episode_id' => episode['id'] }
      { 'title' => episode['name'], 'original_title' => original_title(id, numbers, episode),
        'year' => episode['air_date'].to_s[/\A\d{4}/]&.to_i,
        'abstract' => episode['overview'].to_s, 'source' => source }
    end

    def original_title(id, numbers, episode)
      language = @series_data['original_language']
      return episode['name'] if language == 'fr'
      return unless language.to_s.match?(/\A[a-z]{2}\z/) && episode['id'].is_a?(Integer)

      native_name(id, numbers, episode, language)
    rescue ArgumentError, KeyError, JSON::ParserError, CatalogEnrichment::TmdbClient::Error,
           IOError, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError
      @warnings << 'TMDB (titre original) indisponible ou incomplet.'
      nil
    end

    def native_name(id, numbers, episode, language)
      native_season = @client.get("tv/#{id}/season/#{numbers.season}", language: language)
      native = native_season.fetch('episodes').find do |row|
        row['episode_number'] == numbers.episode && row['id'] == episode['id']
      end
      native&.fetch('name', nil)
    end

    def mapped_proposal(id, season, _series, entries, numbers)
      native = @client.get("tv/#{id}/season/#{numbers.season}", language: @series_data.fetch('original_language'))
      rows = TmdbEpisodeRows.call(season, native, numbers.season)
      rows = entries.empty? ? @stored_edition.call(numbers, rows) : EpisodeEditionMapping.new.call(rows, entries)
      row = rows.find { |item| item['episode_number'] == numbers.episode }
      return unless row

      proposal = row_proposal(id, row)
      proposal['edition_mapping'] = preview(rows) if rows.any? { |item| item.fetch('external_parts', []).size > 1 }
      proposal
    end

    def row_proposal(id, row)
      source = CatalogueEpisodeMetadata.new(source_url: "https://www.themoviedb.org/tv/#{id}").source(row)
      { 'title' => row['title_fr'], 'original_title' => row['title_original'],
        'year' => row['first_air_date'].to_s[/\A\d{4}/]&.to_i, 'abstract' => row['overview_fr'].to_s,
        'source' => source, 'external_parts' => row['external_parts'], 'numbering_source' => row['numbering_source'] }
    end

    def preview(rows)
      rows.map do |row|
        { 'local_number' => row['episode_number'], 'title' => row['title_fr'],
          'external_numbers' => row.fetch('external_parts').pluck('episode_number'),
          'reference_runtime_minutes' => row['reference_runtime_minutes'] }
      end
    end

    def local_links(series)
      scope = @links.where(provider: 'tmdb', record_id: series.subtree.select(:id))
      scope.respond_to?(:to_a) ? scope.to_a.select { |link| link.respond_to?(:evidence) } : []
    end
  end
end
