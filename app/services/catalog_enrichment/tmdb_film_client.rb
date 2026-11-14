# frozen_string_literal: true

require 'uri'

module CatalogEnrichment
  # Uses the existing authenticated transport and a query-specific cache.
  class TmdbFilmClient < TmdbClient
    def search(title:, page: 1, primary_release_year: nil)
      raise ArgumentError, 'A bounded plain title is required' unless valid_title?(title)

      raise ArgumentError, 'Positive bounded page required' unless page.is_a?(Integer) && page.between?(1, 500)

      parameters = { query: title.strip, include_adult: false, page: page }
      parameters[:primary_release_year] = primary_release_year unless primary_release_year.nil?
      query = URI.encode_www_form(parameters)
      payload = get("search/movie?#{query}")
      raise Error, 'Invalid movie search response' unless payload['results'].is_a?(Array)

      raise Error, 'Search page differs from request' unless payload['page'] == page

      payload
    end

    def search_for_year(title:, year:, page: 1)
      raise ArgumentError, 'Invalid release year' unless year.is_a?(Integer) && year.between?(1000, 2999)

      search(title: title, page: page, primary_release_year: year)
    end

    def movie(id:)
      raise ArgumentError, 'Positive integer movie id required' unless id.is_a?(Integer) && id.positive?

      payload = get("movie/#{id}")
      raise Error, 'Movie identity differs from request' unless payload['id'] == id

      payload
    end

    def release_dates(id:)
      raise ArgumentError, 'Positive integer movie id required' unless id.is_a?(Integer) && id.positive?

      payload = get("movie/#{id}/release_dates")
      raise Error, 'Invalid release date response' unless payload['id'] == id && payload['results'].is_a?(Array)

      payload
    end

    private

    def valid_title?(title)
      title.is_a?(String) && title.strip.present? && title.bytesize <= 300 && !title.match?(/[[:cntrl:]]/)
    end

    def validate_path!(path, language)
      endpoint, query = path.split('?', 2)
      valid = endpoint.match?(%r{\Amovie/[1-9]\d*(?:/release_dates)?\z}) && query.nil?
      valid ||= endpoint == 'search/movie' && valid_query?(query)
      return if valid && language.match?(/\A[a-z]{2}(?:-[A-Z]{2})?\z/)

      raise ArgumentError, 'Invalid film endpoint or language'
    end

    def valid_query?(query)
      pairs = URI.decode_www_form(query.to_s)
      values = pairs.to_h
      return false unless pairs.size == values.size && valid_search_keys?(values)

      values['include_adult'] == 'false' && values['page'].match?(/\A[1-9]\d{0,2}\z/) &&
        values['page'].to_i <= 500 && valid_title?(values['query'])
    end

    def valid_search_keys?(values)
      return true if values.keys.sort == %w[include_adult page query]

      values.keys.sort == %w[include_adult page primary_release_year query] &&
        values['primary_release_year'].match?(/\A[12]\d{3}\z/)
    end

    def request_arguments(path, language)
      endpoint, query = path.split('?', 2)
      uri, headers = super(endpoint, language)
      uri.query = URI.encode_www_form(URI.decode_www_form(uri.query) + URI.decode_www_form(query.to_s))
      [uri, headers]
    end

    def search_payload?(payload)
      payload['results'].is_a?(Array) && payload['page'].is_a?(Integer) && payload['page'].positive? &&
        payload['total_pages'].is_a?(Integer)
    end

    def parse_payload(body)
      payload = JSON.parse(body)
      valid = payload.is_a?(Hash) && (payload['id'].is_a?(Integer) || search_payload?(payload))
      raise Error, 'Invalid film response' unless valid

      payload
    end
  end
end
