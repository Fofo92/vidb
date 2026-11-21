module EncoderProjects
  class TmdbSeriesPilot
    # France Télévisions documents the pilot before TMDB's regular-season premiere.
    VERIFIED_PILOTS = {
      88_384 => { 'first_air_date' => '2019-04-12',
                  'url' => 'https://www.francetvpro.fr/contenu-de-presse/17066' }.freeze
    }.freeze

    def initialize(client)
      @client = client
    end

    def call(id, series)
      return VERIFIED_PILOTS.fetch(id) if VERIFIED_PILOTS.key?(id)
      return unless Array(series['seasons']).any? { |season| season['season_number'].zero? }

      season = @client.get("tv/#{id}/season/0")
      pilot = season.fetch('episodes').select { |episode| pilot?(episode) }.min_by { |episode| episode['air_date'] }
      return unless pilot

      { 'first_air_date' => pilot.fetch('air_date'),
        'url' => "https://www.themoviedb.org/tv/#{id}/season/0/episode/#{pilot.fetch('episode_number')}" }
    rescue ArgumentError, KeyError, JSON::ParserError, CatalogEnrichment::TmdbClient::Error,
           IOError, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError, SocketError
      nil
    end

    private

    def pilot?(episode)
      return false unless episode['air_date'].to_s.match?(/\A\d{4}-\d{2}-\d{2}\z/)

      episode['episode_type'] == 'pilot' || episode['name'].to_s.match?(/\bpilote?\b/i)
    end
  end
end
