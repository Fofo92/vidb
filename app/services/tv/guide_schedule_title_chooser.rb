module Tv
  # Applies a title from the current guide to a verified vidb Kaffeine schedule.
  class GuideScheduleTitleChooser
    class Unavailable < StandardError; end

    def initialize(recording_intent:, observation:, client:)
      @recording_intent = recording_intent
      @observation = observation
      @client = client
    end

    def call
      verify_observation!
      name = ProgrammeDisplayName.call(@observation)
      raise Unavailable, "programme has no title" if name.blank?

      RecordingIntentScheduleRenamer.new(
        recording_intent: @recording_intent, client: @client, target_name: name
      ).call
    end

    private

    def verify_observation!
      old = @recording_intent.broadcast_observation
      raise Unavailable, "intent is not selected" unless @recording_intent.status_selected?
      raise Unavailable, "schedule is not managed by vidb" unless managed_link?
      raise Unavailable, "guide time or channel changed" unless same_slot?(old)

      source = old.guide_channel.guide_source
      latest = source.latest_successful_import
      return if latest&.broadcast_observations&.exists?(@observation.id)

      raise Unavailable, "programme is no longer in the current guide"
    end

    def managed_link?
      @recording_intent.kaffeine_schedule_link&.origin_created_by_vidb?
    end

    def same_slot?(old)
      @observation.guide_channel_id == old.guide_channel_id &&
        @observation.starts_at == old.starts_at && @observation.ends_at == old.ends_at
    end
  end
end
