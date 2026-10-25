require 'net/http'
require 'json'
require 'uri'

module EncoderProjects
  class WikipediaClient
    ENDPOINT = 'https://fr.wikipedia.org/w/api.php'.freeze

    def search(title)
      data = get(action: 'query', list: 'search', srsearch: "#{title} film", srnamespace: 0, srlimit: 3)
      data.fetch('query').fetch('search').map { |item| item.fetch('title') }
    end

    def search_series(title)
      data = get(action: 'query', list: 'search', srsearch: "#{title} série télévisée", srnamespace: 0, srlimit: 3)
      data.fetch('query').fetch('search').map { |item| item.fetch('title') }
    end

    def page(title)
      get(action: 'parse', page: title, prop: 'text', redirects: 1).fetch('parse')
    end

    private

    def get(parameters)
      uri = URI(ENDPOINT)
      uri.query = URI.encode_www_form(parameters.merge(format: 'json'))
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 8) do |http|
        http.get(uri.request_uri, 'User-Agent' => 'vidb private catalogue enrichment')
      end
      raise ArgumentError, 'Wikipédia indisponible' unless response.code == '200' && response.body.bytesize <= 2_000_000

      JSON.parse(response.body)
    rescue IOError, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError
      raise ArgumentError, 'Connexion à Wikipédia indisponible ; réessaie ultérieurement.'
    end
  end
end
