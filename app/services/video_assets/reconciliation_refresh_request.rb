# frozen_string_literal: true

require 'tempfile'

module VideoAssets
  class ReconciliationRefreshRequest
    def self.path
      configured = ENV.fetch('VIDB_RECONCILIATION_REFRESH_REQUEST', nil)
      return configured if configured.present?
      return '/srv/vidb/shared/reconciliation-followup/refresh.request' if Rails.env.production?

      nil
    end

    def self.call(path: self.path)
      return unless path

      destination = Pathname.new(path)
      destination.dirname.mkpath
      publish(destination)
    rescue SystemCallError, IOError => e
      Rails.logger.error("Reconciliation refresh request failed: #{e.class}: #{e.message}")
    end

    def self.publish(destination)
      Tempfile.create(['request-', '.tmp'], destination.dirname.to_s) do |file|
        file.chmod(0o600)
        file.write(Time.current.iso8601)
        file.flush
        file.fsync
        File.rename(file.path, destination)
      end
    end
    private_class_method :publish
  end
end
