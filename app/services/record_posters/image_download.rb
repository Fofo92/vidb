# frozen_string_literal: true

require 'net/http'

module RecordPosters
  class ImageDownload
    class Error < StandardError; end

    def call(path)
      raise Error, 'Chemin de pochette invalide' unless path.to_s.match?(%r{\A/[a-zA-Z0-9]+\.(?:jpg|png|webp)\z})

      uri = URI("https://image.tmdb.org/t/p/w342#{path}")
      Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 15) do |http|
        read_image(http, uri)
      end
    rescue IOError, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError
      raise Error, 'Téléchargement indisponible ; réessaie plus tard'
    end

    private

    def read_image(http, uri)
      body = ''.b
      http.request(Net::HTTP::Get.new(uri)) do |response|
        raise Error, "Image indisponible (HTTP #{response.code})" unless response.code == '200'

        response.read_body do |chunk|
          body << chunk
          raise Error, 'Pochette trop volumineuse' if body.bytesize > RecordPoster::MAX_BYTES
        end
      end
      body
    end
  end
end
