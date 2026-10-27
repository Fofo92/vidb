require 'uri'

module EncoderProjects
  class SeriesCatalogueSearch
    def initialize(client: nil)
      @client = client
    end

    def call(query)
      text = query.to_s.strip
      raise ArgumentError, 'Titre ou lien limité à 300 caractères' unless text.present? && text.bytesize <= 300

      id = text[%r{\Ahttps://(?:www\.)?themoviedb\.org/tv/([1-9]\d*)(?:[-/?#].*)?\z}, 1]
      return [candidate(client.get("tv/#{id}"))] if id
      return [] if external_film_link?(text)

      title = wikipedia_title(text)
      client.search(title: title).fetch('results').first(5).map { |row| candidate(row) }
    rescue ArgumentError, KeyError, JSON::ParserError, CatalogEnrichment::TmdbClient::Error,
           IOError, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError
      []
    end

    private

    def external_film_link?(text)
      text.start_with?('https://www.themoviedb.org/', 'https://themoviedb.org/',
                       'https://www.senscritique.com/', 'https://senscritique.com/')
    end

    def wikipedia_title(text)
      prefix = 'https://fr.wikipedia.org/wiki/'
      return text unless text.start_with?(prefix)

      URI.decode_www_form_component(text.delete_prefix(prefix)).tr('_', ' ')
    end

    def candidate(row)
      { 'tmdb_id' => row.fetch('id'), 'title' => row.fetch('name'), 'original_title' => row['original_name'],
        'year' => row['first_air_date'].to_s[/\A\d{4}/]&.to_i }
    end

    def client
      @client ||= TmdbSeriesClient.new(cache_dir: Rails.root.join('tmp/catalogue-episodes'))
    end
  end
end
