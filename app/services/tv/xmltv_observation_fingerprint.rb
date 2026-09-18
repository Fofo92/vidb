require "digest"
require "json"
require "time"

module Tv
  class XmltvObservationFingerprint
    VERSION = 1

    METADATA_FIELDS = %i[
      titles
      subtitles
      descriptions
      categories
      episode_numbers
    ].freeze

    def initialize(guide_source:, programme:)
      @guide_source = guide_source
      @programme = programme
    end

    def call
      Digest::SHA256.hexdigest(
        JSON.generate(canonical_payload)
      )
    end

    private

    def canonical_payload
      {
        fingerprint_version: VERSION,
        guide_source_name: canonical_string(@guide_source.name),
        channel_id: canonical_string(@programme.channel_id),
        starts_at: canonical_time(@programme.starts_at),
        ends_at: canonical_time(@programme.ends_at)
      }.merge(canonical_metadata)
    end

    def canonical_metadata
      METADATA_FIELDS.to_h do |field|
        [
          field,
          canonical_entries(@programme.public_send(field))
        ]
      end
    end

    def canonical_entries(entries)
      entries
        .map { |entry| canonical_entry(entry) }
        .sort_by { |entry| JSON.generate(entry) }
    end

    def canonical_entry(entry)
      entry
        .to_h
        .transform_keys(&:to_s)
        .sort
        .to_h
        .transform_values { |value| canonical_value(value) }
    end

    def canonical_value(value)
      return canonical_string(value) if value.is_a?(String)

      value
    end

    def canonical_string(value)
      value.unicode_normalize(:nfc)
    end

    def canonical_time(value)
      value.utc.iso8601(6)
    end
  end
end
