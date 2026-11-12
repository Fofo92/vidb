require 'uri'

module EncoderProjects
  class TmdbSeriesClient < CatalogEnrichment::TmdbClient
    MAX_SEARCH_PAGES = 20

    def search(title:, page: 1)
      raise ArgumentError, 'Titre de série invalide' unless valid_title?(title)
      raise ArgumentError, 'Page de recherche invalide' unless valid_page?(page)

      query = URI.encode_www_form(query: title.strip, include_adult: false, page: page)
      payload = get("search/tv?#{query}")
      unless payload['results'].is_a?(Array) && payload['page'] == page
        raise Error,
              'Réponse de recherche de série invalide'
      end

      payload
    end

    private

    def valid_title?(title)
      title.is_a?(String) && title.strip.present? && title.bytesize <= 300 && !title.match?(/[[:cntrl:]]/)
    end

    def valid_page?(page)
      page.is_a?(Integer) && page.between?(1, MAX_SEARCH_PAGES)
    end

    def validate_path!(path, language)
      endpoint, query = path.split('?', 2)
      valid = endpoint.match?(%r{\Atv/[1-9]\d*(?:/season/\d+(?:/episode/[1-9]\d*)?)?\z}) && query.nil?
      valid ||= endpoint == 'search/tv' && valid_query?(query)
      return if valid && language.match?(/\A[a-z]{2}(?:-[A-Z]{2})?\z/)

      raise ArgumentError, 'Recherche de série invalide'
    end

    def valid_query?(query)
      pairs = URI.decode_www_form(query.to_s)
      values = pairs.to_h
      pairs.size == 3 && values.keys.sort == %w[include_adult page query] && valid_query_page?(values['page']) &&
        values['include_adult'] == 'false' && valid_title?(values['query'])
    end

    def valid_query_page?(page)
      page.to_s.match?(/\A[1-9]\d*\z/) && valid_page?(page.to_i)
    end

    def request_arguments(path, language)
      endpoint, query = path.split('?', 2)
      uri, headers = super(endpoint, language)
      uri.query = URI.encode_www_form(URI.decode_www_form(uri.query) + URI.decode_www_form(query.to_s))
      [uri, headers]
    end

    def parse_payload(body)
      payload = JSON.parse(body)
      valid = payload.is_a?(Hash) && (payload['id'].is_a?(Integer) ||
                                    (payload['results'].is_a?(Array) && valid_page?(payload['page'])))
      raise Error, 'Réponse TMDB de série invalide' unless valid

      payload
    end
  end
end
