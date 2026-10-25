require 'json'
require 'uri'

module EncoderProjects
  class Settings
    PATH = '/srv/vidb/shared/encoder-bridge/server.json'.freeze

    def self.read
      raise ArgumentError, 'Passerelle non configurée' unless File.file?(PATH) && File.size(PATH) <= 4096

      data = JSON.parse(File.read(PATH))
      validate!(data)
      data
    end

    def self.validate!(data)
      raise ArgumentError, 'Configuration de passerelle invalide' unless data.is_a?(Hash)

      valid = valid_url?(URI(data.fetch('url'))) && data.fetch('token').to_s.match?(/\A[0-9a-f]{64}\z/)
      valid &&= data['user_id'].is_a?(Integer) && data['user_id'].positive?
      raise ArgumentError, 'Configuration de passerelle invalide' unless valid
    end

    def self.valid_url?(uri)
      uri.scheme == 'https' && uri.host.present? && uri.userinfo.nil? &&
        [nil, '', '/'].include?(uri.path) && uri.query.nil? && uri.fragment.nil?
    end
  end
end
