module Tv
  class RecordingIntentScheduleCanceller
    class LinkedScheduleMismatch < StandardError; end
    class TooLateToCancel < StandardError; end

    GUARD_SECONDS = 120

    def initialize(
      recording_intent:,
      client:,
      manager: nil,
      lock: KaffeineScheduleLock.new,
      clock: -> { Time.current }
    )
      @recording_intent = recording_intent
      @client = client
      @manager = manager || KaffeineScheduleManager.new(client:)
      @lock = lock
      @clock = clock
    end

    def call
      @lock.synchronize do
        link = KaffeineScheduleLink.find_by(recording_intent_id: @recording_intent.id)
        remove_managed_schedule(link) if link&.origin_created_by_vidb?
        link&.destroy!
        @recording_intent.update!(status: "cancelled") if @recording_intent.status_selected?
        @recording_intent
      end
    end

    private

    def remove_managed_schedule(link)
      schedule = @client.schedules.find { |entry| entry.key == link.kaffeine_key }
      message = "linked Kaffeine schedule is missing or changed"
      raise LinkedScheduleMismatch, message unless schedule && link.matches?(schedule)

      deadline = schedule.starts_at - GUARD_SECONDS
      raise TooLateToCancel, "Kaffeine schedule is too close to its start" if @clock.call >= deadline

      @manager.remove(schedule)
    end
  end
end
