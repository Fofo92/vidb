module Tv
  class RecordingIntentScheduleAttributes
    class Unavailable < StandardError; end

    def initialize(recording_intent:)
      @recording_intent = recording_intent
    end

    def call
      raise Unavailable, "recording intent is not selected" unless @recording_intent.status_selected?

      return overridden_attributes if @recording_intent.capture_override.present?

      {
        name: programme_name,
        channel: kaffeine_name,
        starts_at: @recording_intent.capture_starts_at,
        duration_seconds: duration_seconds,
        repeat: 0
      }
    end

    def base_name
      title = ProgrammeDisplayName.title(@recording_intent.broadcast_observation)
      raise Unavailable, "programme has no title" if title.blank?

      title
    end

    private

    def overridden_attributes
      @recording_intent.capture_override.symbolize_keys.merge(starts_at: @recording_intent.capture_starts_at)
    end

    def programme_name
      ProgrammeDisplayName.call(@recording_intent.broadcast_observation) || base_name
    end

    def kaffeine_name
      name = @recording_intent.broadcast_observation.guide_channel.channel&.kaffeine_name
      raise Unavailable, "channel has no Kaffeine mapping" if name.blank?

      name
    end

    def duration_seconds
      duration = (@recording_intent.capture_ends_at - @recording_intent.capture_starts_at).to_i
      raise Unavailable, "capture duration is outside Kaffeine range" unless duration.between?(1, 86_399)

      duration
    end
  end
end
