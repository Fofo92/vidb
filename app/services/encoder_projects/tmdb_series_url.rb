require 'uri'

module EncoderProjects
  class TmdbSeriesUrl
    PATH = %r{\A/tv/([1-9]\d*)(?:-[^/]+)?(?:/season/(\d+)/episode/([1-9]\d*))?/?\z}

    def self.options(value)
      return {} if value.blank?

      uri = URI.parse(value.to_s.strip)
      match = PATH.match(uri.path.to_s)
      raise ArgumentError unless valid_uri?(uri) && match

      result = { tmdb_series_id: Integer(match[1], 10) }
      result[:tmdb_episode] = { 'season' => Integer(match[2], 10), 'episode' => Integer(match[3], 10) } if match[2]
      result
    rescue URI::InvalidURIError, ArgumentError
      raise ArgumentError, 'Saisis une URL TMDB de série ou d’épisode : https://www.themoviedb.org/tv/42083'
    end

    def self.valid_uri?(uri)
      %w[http https].include?(uri.scheme) && %w[themoviedb.org www.themoviedb.org].include?(uri.host) &&
        uri.userinfo.nil? && [80, 443].include?(uri.port)
    end
    private_class_method :valid_uri?

    def self.id(value)
      options(value).fetch(:tmdb_series_id) { raise ArgumentError, 'URL TMDB requise' }
    end
  end
end
