module EncoderProjects
  class TmdbEpisodeUrlProposal
    attr_reader :series_data

    def initialize(client:, warnings:)
      @client = client
      @warnings = warnings
    end

    def call(id, reference)
      @series_data = @client.get("tv/#{id}")
      unless @series_data['id'] == id
        raise ArgumentError, 'Identité de série TMDB différente : recharge la proposition.'
      end

      path = "tv/#{id}/season/#{reference.fetch('season')}/episode/#{reference.fetch('episode')}"
      episode = @client.get(path)
      verify!(episode, reference)
      proposal(id, reference, path, episode)
    end

    private

    def verify!(episode, reference)
      valid = episode['id'].is_a?(Integer) && episode['id'].positive? &&
              episode['season_number'] == reference.fetch('season') &&
              episode['episode_number'] == reference.fetch('episode') &&
              (!reference['episode_id'] || reference['episode_id'] == episode['id'])
      raise ArgumentError, 'Identité de l’épisode TMDB différente : recharge la proposition.' unless valid
    end

    def proposal(id, reference, path, episode)
      source = { 'provider' => 'tmdb', 'url' => "https://www.themoviedb.org/#{path}",
                 'episode_id' => episode.fetch('id'), 'first_air_date' => episode['air_date'].to_s }
      { 'title' => episode['name'], 'original_title' => original_title(path, episode),
        'year' => episode['air_date'].to_s[/\A\d{4}/]&.to_i, 'abstract' => episode['overview'].to_s,
        'source' => source, 'reference_runtime_minutes' => episode['runtime'],
        'tmdb_series_title' => @series_data['name'], 'tmdb_episode_title' => episode['name'],
        'tmdb_episode_reference' => reference.merge('series_id' => id, 'episode_id' => episode.fetch('id')) }
    end

    def original_title(path, episode)
      language = @series_data['original_language'].to_s
      return episode['name'] if language == 'fr'
      return unless language.match?(/\A[a-z]{2}\z/)

      native = @client.get(path, language: language)
      raise ArgumentError unless native['id'] == episode['id']

      native['name']
    rescue ArgumentError, KeyError, JSON::ParserError, CatalogEnrichment::TmdbClient::Error,
           IOError, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError
      @warnings << 'TMDB (titre original) indisponible ou incomplet.'
      nil
    end
  end
end
