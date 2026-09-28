module Tv
  class RecordingIntentScheduleAttributes
    class Unavailable < StandardError; end

    def initialize(recording_intent:)
      @recording_intent = recording_intent
    end

    def call
      raise Unavailable, "recording intent is not selected" unless @recording_intent.status_selected?

      {
        name: programme_name,
        channel: kaffeine_name,
        starts_at: @recording_intent.capture_starts_at,
        duration_seconds: duration_seconds,
        repeat: 0
      }
    end

    def base_name
      titles = @recording_intent.broadcast_observation.titles
      title = titles.find { |entry| entry["language"] == "fr" && entry["value"].present? } ||
              titles.find { |entry| entry["value"].present? }
      raise Unavailable, "programme has no title" unless title

      title.fetch("value")
    end

    private

    def programme_name
      episode = ProgrammeEpisodeLabel.call(@recording_intent.broadcast_observation)
      episode ? "#{base_name} — #{episode}" : base_name
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
