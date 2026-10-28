# frozen_string_literal: true

require 'net/http'
require 'timeout'

module EncoderProjects
  # Use the local hierarchy and TV identity, not an episode title as a film query.
  class SeriesOriginalLanguage
    UNKNOWN = { 'status' => 'unknown' }.freeze

    def self.reference(record)
      case record.record_kind
      when 'series' then record
      when 'season' then parent(record, 'series')
      when 'episode'
        season = parent(record, 'season')
        parent(season, 'series') if season
      end
    end

    def self.parent(record, kind)
      parent = record.parent if record.respond_to?(:parent)
      parent if parent&.record_kind == kind
    end
    private_class_method :parent

    def initialize(client: nil, links: CatalogueEpisodeLink)
      @client = client
      @links = links
    end

    def call(series)
      ids = linked_ids(series)
      return UNKNOWN if ids.many?

      id = ids.first || searched_id(series)
      return UNKNOWN unless id

      data = client.get("tv/#{id}")
      return UNKNOWN unless data['id'] == id && matching?(data, series)

      evidence(data, series)
    rescue CatalogEnrichment::TmdbClient::Error, IOError, SystemCallError, Timeout::Error,
           JSON::ParserError, KeyError, ArgumentError, TypeError
      UNKNOWN
    end

    private

    def linked_ids(series)
      @links.where(provider: 'tmdb', record_id: series.subtree.select(:id))
            .distinct.limit(2).pluck(:external_series_id)
    end

    def searched_id(series)
      title = series.french_title.presence || series.original_title
      rows = client.search(title: title).fetch('results').select { |row| matching?(row, series) }
      rows.sole.fetch('id') if rows.one?
    end

    def matching?(row, series)
      return false unless row.is_a?(Hash)

      local = SynopsisPreference.normalized_titles([series.french_title, series.original_title])
      remote = SynopsisPreference.normalized_titles(row.values_at('name', 'original_name'))
      return false unless local.intersect?(remote)

      series.year.blank? || row['first_air_date'].to_s.first(4) == series.year.to_s
    end

    def evidence(data, series)
      language = data['original_language']
      return UNKNOWN unless unambiguous?(data, language)

      { 'status' => language == 'fr' ? 'french' : 'foreign', 'language' => language,
        'provider' => 'tmdb', 'scope' => 'series', 'url' => "https://www.themoviedb.org/tv/#{data.fetch('id')}",
        'title' => data['name'], 'year' => series.year }
    end

    def unambiguous?(data, language)
      return false unless language.is_a?(String) && language.match?(/\A[a-z]{2}\z/)
      return false if %w[xx zz].include?(language)

      languages = data.fetch('languages', [])
      languages.is_a?(Array) && languages.all? { |code| code == language } &&
        spoken_language?(data.fetch('spoken_languages', []), language)
    end

    def spoken_language?(spoken, language)
      spoken.is_a?(Array) && spoken.all? { |item| item.is_a?(Hash) && item['iso_639_1'] == language }
    end

    def client
      @client ||= TmdbSeriesClient.new(cache_dir: Rails.root.join('tmp/catalogue-episodes'),
                                       transport: method(:request))
    end

    def request(uri, headers)
      Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 0.3, read_timeout: 0.5) do |http|
        http.max_retries = 0
        http.request(Net::HTTP::Get.new(uri, headers))
      end
    end
  end
end
