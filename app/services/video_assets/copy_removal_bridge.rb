# frozen_string_literal: true

require 'open3'
require 'json'

module VideoAssets
  # A fixed sudo command, with a bounded JSON request and no shell interpolation.
  class CopyRemovalBridge
    class Error < StandardError; end

    def call(request)
      user = ENV.fetch('VIDB_COPY_TRASH_USER', 'pascal')
      command = ['/usr/bin/sudo', '-n', '-u', user, '--', '/usr/local/libexec/vidb-copy-trash']
      output, error, status = Open3.capture3(*command, stdin_data: JSON.generate(request))
      raise Error, error.strip.presence || 'Service de corbeille indisponible.' unless status.success?
      raise Error, 'Réponse de corbeille invalide.' if output.bytesize > 16_384

      JSON.parse(output)
    rescue SystemCallError, JSON::ParserError => e
      raise Error, "Service de corbeille inaccessible : #{e.message}"
    end
  end
end
