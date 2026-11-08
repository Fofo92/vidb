require "net/http"
require "json"

class DvdBarcodeLookup
  class Error < StandardError; end

  ENDPOINT = "https://api.upcitemdb.com/prod/trial/lookup".freeze

  def call(ean)
    response = lookup(ean)
    return [] if response.code == "404"
    raise Error unless response.is_a?(Net::HTTPSuccess)

    titles(JSON.parse(response.body), ean)
  rescue JSON::ParserError, IOError, SystemCallError, Timeout::Error, SocketError, OpenSSL::SSL::SSLError
    raise Error
  end

  private

  def lookup(ean)
    uri = URI(ENDPOINT)
    uri.query = URI.encode_www_form(upc: ean)
    Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 3, read_timeout: 4) do |http|
      http.get(uri.request_uri)
    end
  end

  def titles(payload, ean)
    raise Error unless payload.is_a?(Hash) && payload["items"].is_a?(Array)

    payload["items"].filter_map do |item|
      next unless item.is_a?(Hash) && item["ean"] == ean

      item["title"].to_s.strip.presence
    end.uniq
  end
end
