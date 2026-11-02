# frozen_string_literal: true

module VideoAssets
  # Read the existing completed inventory; never scan /videos in a web request.
  class InventorySnapshot
    def initialize(path: ReconciliationWorkbench::Planner.followup_path)
      @path = Pathname.new(path)
    end

    def call
      raise ArgumentError, 'Inventaire trop volumineux' if @path.size > 64.megabytes

      document = JSON.parse(@path.read)
      raise ArgumentError, 'Document invalide' unless document.is_a?(Hash)

      source = document.deep_symbolize_keys
      validate_source(source)
      source
    rescue SystemCallError, JSON::ParserError, ArgumentError, TypeError, KeyError
      nil
    end

    private

    def validate_source(source)
      valid = source[:format] == ReconciliationFollowup::FORMAT && source[:version] == 1
      valid &&= source.dig(:source_inventory, :roots) == ['/videos'] && source[:entries].is_a?(Array)
      raise ArgumentError, 'Inventaire incompatible' unless valid

      Time.iso8601(source.fetch(:inventory_at))
      source[:entries].each do |entry|
        raise ArgumentError, 'Entrée invalide' unless entry.is_a?(Hash) && entry[:path].is_a?(String)

        Time.iso8601(entry.fetch(:modified_at))
      end
    end
  end
end
