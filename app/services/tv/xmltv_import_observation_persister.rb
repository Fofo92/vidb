module Tv
  class XmltvImportObservationPersister
    def initialize(guide_source:, guide_import:, guide_channels:, programmes:)
      @guide_source = guide_source
      @guide_import = guide_import
      @guide_channels = guide_channels
      @programmes = programmes
    end

    def call
      @programmes.each do |programme|
        persist_observation(programme)
      end
    end

    private

    def persist_observation(programme)
      observation = find_or_create_observation(
        programme,
        @guide_channels.fetch(programme.channel_id)
      )

      @guide_import.guide_import_observations.create!(
        broadcast_observation: observation
      )
    end

    def find_or_create_observation(programme, guide_channel)
      fingerprint = observation_fingerprint(programme)

      BroadcastObservation.find_or_create_by!(
        fingerprint_version: XmltvObservationFingerprint::VERSION,
        fingerprint: fingerprint
      ) do |observation|
        observation.assign_attributes(
          observation_attributes(programme, guide_channel)
        )
      end
    end

    def observation_fingerprint(programme)
      XmltvObservationFingerprint.new(
        guide_source: @guide_source,
        programme: programme
      ).call
    end

    def observation_attributes(programme, guide_channel)
      observation_identity(programme, guide_channel).merge(
        observation_metadata(programme)
      )
    end

    def observation_identity(programme, guide_channel)
      {
        guide_channel: guide_channel,
        starts_at: programme.starts_at,
        ends_at: programme.ends_at,
        source_start: programme.source_start,
        source_stop: programme.source_stop
      }
    end

    def observation_metadata(programme)
      {
        titles: stringify_entries(programme.titles),
        subtitles: stringify_entries(programme.subtitles),
        descriptions: stringify_entries(programme.descriptions),
        categories: stringify_entries(programme.categories),
        episode_numbers: stringify_entries(programme.episode_numbers)
      }
    end

    def stringify_entries(entries)
      entries.map(&:stringify_keys)
    end
  end
end
