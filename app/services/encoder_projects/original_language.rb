# frozen_string_literal: true

require 'net/http'
require 'timeout'

module EncoderProjects
  # Resolve an identified film, never a similarly named episode or a country.
  class OriginalLanguage
    UNKNOWN = { 'status' => 'unknown' }.freeze

    def self.call(record)
      return UNKNOWN unless record.respond_to?(:record_kind) && record.record_kind == 'standalone_video' &&
                            record.year.present?

      key = ['encoder-original-language-v1', record.id, record.french_title, record.original_title, record.year]
      Rails.cache.fetch(key, expires_in: 10.minutes) { new.call(record) }
    end

    def initialize(client: nil)
      @client = client || CatalogEnrichment::TmdbFilmClient.new(
        cache_dir: Rails.root.join('tmp/encoder-original-language'), transport: method(:request)
      )
    end

    def call(record)
      movie = matching_movie(record)
      movie ? evidence(movie, record.year) : UNKNOWN
    rescue CatalogEnrichment::TmdbClient::Error, IOError, SystemCallError, Timeout::Error,
           JSON::ParserError, KeyError, ArgumentError, TypeError
      UNKNOWN
    end

    private

    def matching_movie(record)
      title = record.original_title.presence || record.french_title
      titles = SynopsisPreference.normalized_titles([record.original_title, record.french_title])
      rows = @client.search(title: title).fetch('results').select { |row| matches?(row, record.year, titles) }
      return unless rows.one?

      movie = @client.movie(id: rows.sole.fetch('id'))
      movie if matches?(movie, record.year, titles)
    end

    def matches?(movie, year, titles)
      return false unless movie.is_a?(Hash) && movie['release_date'].to_s.first(4) == year.to_s

      SynopsisPreference.normalized_titles([movie['title'], movie['original_title']]).intersect?(titles)
    end

    def evidence(movie, year)
      language = movie['original_language']
      return UNKNOWN unless unambiguous?(movie, language)

      { 'status' => language == 'fr' ? 'french' : 'foreign', 'language' => language,
        'provider' => 'tmdb', 'url' => "https://www.themoviedb.org/movie/#{movie.fetch('id')}",
        'title' => movie['title'], 'year' => year }
    end

    def unambiguous?(movie, language)
      return false unless language.is_a?(String) && language.match?(/\A[a-z]{2}\z/)
      return false if %w[xx zz].include?(language)

      spoken = movie.fetch('spoken_languages', [])
      spoken.is_a?(Array) && spoken.all? { |item| item.is_a?(Hash) && item['iso_639_1'] == language }
    end

    # Keep identification responsive: at most one search and one detail request.
    def request(uri, headers)
      Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 0.3, read_timeout: 0.5) do |http|
        http.max_retries = 0
        http.request(Net::HTTP::Get.new(uri, headers))
      end
    end
  end
end
