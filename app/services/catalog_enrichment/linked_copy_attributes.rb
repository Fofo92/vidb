# frozen_string_literal: true

module CatalogEnrichment
  class LinkedCopyAttributes
    def initialize(evidence:, medium:)
      @evidence = evidence
      @medium = medium
    end

    def plan(record, entry, observed)
      validate_observation!(entry, observed)
      asset = existing_or_new(record, entry.fetch(:path))
      raise ArgumentError, 'Existing support conflicts with batch' if asset.medium_id && asset.medium_id != @medium.id

      [asset, attributes(asset, observed, entry)]
    end

    private

    def validate_observation!(entry, observed)
      valid = observed.fetch(:path) == entry.fetch(:path) && observed.fetch(:byte_size) == entry.fetch(:size) &&
              observed.fetch(:technical_details).dig('storage', 'uuid') == @evidence.fetch('storage_uuid')
      raise ArgumentError, "File size or storage changed: #{entry.fetch(:path)}" unless valid
    end

    def existing_or_new(record, path)
      assets = VideoAsset.where(status: 'present').where('record_id = ? OR last_known_path = ?', record.id, path).to_a
      return VideoAsset.new(record: record, last_known_path: path, status: 'present') if assets.empty?
      return assets.first if assets.one? && assets.first.record_id == record.id && assets.first.last_known_path == path

      raise ArgumentError, "Conflicting copy for episode #{record.id}"
    end

    def attributes(asset, observed, entry)
      details = asset.technical_details.merge(observed.fetch(:technical_details)).merge(
        'measured_duration_seconds' => observed.fetch(:measured_duration_seconds),
        'observed_at' => observed.fetch(:observed_at).iso8601,
        'reconciliation' => { 'basis' => 'confirmed_local_tmdb_link', 'tmdb_episode_id' => entry[:tmdb_episode_id],
                              'source_inventory' => @evidence['source_inventory'] }
      )
      observed.slice(:byte_size, :duration_minutes, :container, :observed_at).merge(
        medium_id: @medium.id, technical_details: details
      )
    end
  end
end
