# frozen_string_literal: true

module CatalogEnrichment
  class BroadcastPartCopy
    def initialize(evidence:)
      @evidence = evidence.deep_symbolize_keys
      @medium = Medium.find_by!(short_name: 'HD')
    end

    def plan(record, entry, observed)
      validate_observation!(entry, observed)

      asset = existing_or_new(record, entry)
      attributes = observed.slice(:byte_size, :duration_minutes, :container, :observed_at)
      attributes.merge!(medium: @medium, technical_details: details(asset, entry, observed))
      asset.assign_attributes(attributes)
      raise ActiveRecord::RecordInvalid, asset unless asset.valid?

      [asset, attributes]
    end

    private

    def storage(observed)
      observed.fetch(:technical_details).dig('storage', 'uuid')
    end

    def validate_observation!(entry, observed)
      valid = storage(observed) == @evidence.fetch(:storage_uuid) && observed[:path] == entry[:path] &&
              observed[:byte_size] == entry[:size]
      raise ArgumentError, 'File identity or storage volume differs' unless valid
    end

    def existing_or_new(record, entry)
      asset = VideoAsset.find_by(status: 'present', last_known_path: entry.fetch(:path))
      return new_asset(record, entry) unless asset

      valid = asset.record_id == record.id && asset.broadcast_part_number == entry.fetch(:part) &&
              [nil, @medium.id].include?(asset.medium_id)
      raise ArgumentError, 'Existing copy identity or medium conflicts' unless valid

      asset
    end

    def new_asset(record, entry)
      VideoAsset.new(record: record, last_known_path: entry.fetch(:path), status: 'present',
                     broadcast_part_number: entry.fetch(:part))
    end

    def details(asset, entry, observed)
      asset.technical_details.merge(observed.fetch(:technical_details)).merge(
        'measured_duration_seconds' => observed.fetch(:measured_duration_seconds),
        'broadcast_part' => { 'number' => entry[:part], 'count' => 2, 'broadcaster' => 'M6',
                              'local_episode_number' => local_number(entry),
                              'basis' => @evidence.fetch(:confirmed_basis) }
      )
    end

    def local_number(entry)
      stem = File.basename(entry[:path], File.extname(entry[:path]))
      BroadcastPartName.call(stem: stem, path: entry[:path])[:local_number]
    end
  end
end
