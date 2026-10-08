# frozen_string_literal: true

require 'net/http'
require 'json'
require 'digest'

module CatalogEnrichment
  # Retrieves public catalogue data; credentials never enter cached payloads.
  class TmdbClient
    class Error < StandardError; end

    def initialize(cache_dir:, token: ENV.fetch('TMDB_READ_ACCESS_TOKEN', nil), api_key: ENV.fetch('TMDB_API_KEY', nil),
                   transport: nil, refresh: false)
      @cache_dir = Pathname.new(cache_dir)
      @token = token
      @api_key = api_key
      @transport = transport || method(:request)
      @refresh = refresh
    end

    def get(path, language: 'fr-FR')
      validate_path!(path, language)
      cache = @cache_dir.join("#{Digest::SHA256.hexdigest("#{path}:#{language}")}.json")
      return JSON.parse(cache.read) unless @refresh || !cache.file?

      raise Error, 'Configure TMDB_READ_ACCESS_TOKEN or TMDB_API_KEY' if @token.to_s.empty? && @api_key.to_s.empty?

      payload = fetch(path, language)
      save_cache(cache, payload)
      payload
    end

    private

    def save_cache(cache, payload)
      @cache_dir.mkpath
      temporary = cache.sub_ext(".#{Process.pid}.tmp")
      temporary.write(JSON.generate(payload))
      File.rename(temporary, cache)
    ensure
      temporary&.delete if temporary&.exist?
    end

    def validate_path!(path, language)
      valid = path.match?(%r{\Atv/[1-9]\d*(?:/season/\d+)?\z}) && language.match?(/\A[a-z]{2}(?:-[A-Z]{2})?\z/)
      raise ArgumentError, 'Invalid TMDB endpoint or language' unless valid
    end

    def fetch(path, language)
      response = @transport.call(*request_arguments(path, language))
      raise Error, "TMDB HTTP #{response.code}; no catalogue change" unless response.code.to_i == 200

      parse_payload(response.body)
    rescue JSON::ParserError
      raise Error, 'Invalid JSON response from TMDB'
    rescue IOError, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError
      raise Error, 'TMDB network failure; retry later'
    end

    def request_arguments(path, language)
      uri = URI("https://api.themoviedb.org/3/#{path}")
      query = { language: language }
      query[:api_key] = @api_key if @token.to_s.empty?
      uri.query = URI.encode_www_form(query)
      headers = { 'Accept' => 'application/json' }
      headers['Authorization'] = "Bearer #{@token}" unless @token.to_s.empty?
      [uri, headers]
    end

    def parse_payload(body)
      payload = JSON.parse(body)
      raise Error, 'Invalid TMDB response' unless payload.is_a?(Hash) && payload['id'].is_a?(Integer)

      payload
    end

    def request(uri, headers)
      Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 30) do |http|
        http.request(Net::HTTP::Get.new(uri, headers))
      end
    end
  end
end
