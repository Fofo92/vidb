require 'net/http'
require 'uri'
require 'nokogiri'

module EncoderProjects
  class SenscritiqueClient
    class Error < StandardError; end

    HOST = 'www.senscritique.com'.freeze
    FILM_PATH = %r{\A/film/[^/?#]+/[1-9]\d*\z}
    LIMIT = 2_000_000

    def initialize(transport: nil)
      @transport = transport || method(:request)
    end

    def film_url(value)
      uri = URI.parse(value.to_s)
      return unless uri.is_a?(URI::HTTPS) && [HOST, 'senscritique.com'].include?(uri.host) &&
                    uri.port == 443 && uri.userinfo.nil? && uri.path.match?(FILM_PATH)

      "https://#{HOST}#{uri.path}"
    rescue URI::InvalidURIError
      nil
    end

    def search(title)
      uri = URI::HTTPS.build(host: HOST, path: '/search', query: URI.encode_www_form(query: title))
      document = Nokogiri::HTML(get(uri))
      document.css('a[href]').filter_map do |link|
        href = link['href']
        film_url(href.start_with?('/') ? "https://#{HOST}#{href}" : href)
      end.uniq.first(3)
    end

    def page(url)
      canonical = film_url(url)
      raise Error, 'Lien SensCritique de film invalide' unless canonical

      get(URI(canonical))
    end

    private

    def get(uri)
      response = @transport.call(uri)
      raise Error, "SensCritique indisponible (HTTP #{response.code})" unless response.code.to_s == '200'
      raise Error, 'Réponse SensCritique trop volumineuse' if response.body.bytesize > LIMIT

      response.body
    rescue IOError, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError
      raise Error, 'Connexion à SensCritique indisponible ; réessaie ultérieurement.'
    end

    def request(uri)
      Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 8) do |http|
        http.request_get(uri.request_uri, 'User-Agent' => 'vidb private catalogue enrichment') do |response|
          body = +''
          response.read_body do |chunk|
            body << chunk
            raise Error, 'Réponse SensCritique trop volumineuse' if body.bytesize > LIMIT
          end
          return Struct.new(:code, :body).new(response.code, body)
        end
      end
    end
  end
end
