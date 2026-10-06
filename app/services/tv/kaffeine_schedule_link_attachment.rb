module Tv
  class KaffeineScheduleLinkAttachment
    def initialize(recording_intent:, schedule:, origin:, link: nil, clock: -> { Time.current })
      @recording_intent = recording_intent
      @schedule = schedule
      @origin = origin
      @link = link
      @clock = clock
    end

    def call
      KaffeineScheduleLink.transaction do
        retire_previous_owner
        link = @link || KaffeineScheduleLink.new(recording_intent: @recording_intent)
        reject_collision!(link) if link.retired?
        link.update!(snapshot)
        link
      end
    end

    private

    def retire_previous_owner
      previous = KaffeineScheduleLink.active.lock.find_by(kaffeine_key: @schedule.key)
      return unless previous && previous != @link

      reject_collision!(previous) unless expired?(previous) && !previous.matches?(@schedule)
      previous.update!(retired_at: @clock.call)
    end

    def expired?(link)
      now = @clock.call
      link.repeat_mask.zero? && link.starts_at + link.duration_seconds <= now &&
        link.recording_intent.capture_ends_at <= now
    end

    def reject_collision!(link)
      link.errors.add(:kaffeine_key, "is still linked to another schedule or is historical")
      raise ActiveRecord::RecordInvalid, link
    end

    def snapshot
      {
        kaffeine_key: @schedule.key, origin: @origin,
        name: @schedule.name, channel: @schedule.channel,
        starts_at: @schedule.starts_at,
        duration_seconds: @schedule.duration_seconds, repeat_mask: @schedule.repeat
      }
    end
  end
end
