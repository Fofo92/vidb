require 'uri'

module EncoderProjects
  class TmdbSeriesUrl
    def self.id(value)
      uri = URI.parse(value.to_s.strip)
      match = %r{\A/tv/([1-9]\d*)(?:-[^/]+)?/?\z}.match(uri.path.to_s)
      valid = %w[http https].include?(uri.scheme) &&
              %w[themoviedb.org www.themoviedb.org].include?(uri.host) &&
              uri.userinfo.nil? && [80, 443].include?(uri.port) && match
      raise ArgumentError unless valid

      Integer(match[1], 10)
    rescue URI::InvalidURIError, ArgumentError
      raise ArgumentError, 'Saisis une URL de série TMDB : https://www.themoviedb.org/tv/42083'
    end
  end
end
