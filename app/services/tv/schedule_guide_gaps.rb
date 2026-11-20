module Tv
  # Identifies linked captures whose original slot is absent from the latest guide.
  class ScheduleGuideGaps
    def call(intents)
      active = intents.select { |intent| future_link?(intent) }
      active.group_by { |intent| intent.broadcast_observation.guide_channel.guide_source }
            .flat_map { |source, group| missing_slots(source.latest_successful_import, group) }.to_set
    end

    private

    def future_link?(intent)
      link = intent.kaffeine_schedule_link
      link && !link.retired? && intent.capture_ends_at > Time.current
    end

    def missing_slots(import, intents)
      return [] unless import

      slots = intents.group_by { |intent| slot(intent) }
      channels, starts = slots.keys.transpose
      found = import.broadcast_observations.where(guide_channel_id: channels.uniq, starts_at: starts.uniq)
                    .pluck(:guide_channel_id, :starts_at, :ends_at)
      (slots.keys - found).flat_map { |key| slots.fetch(key).map(&:id) }
    end

    def slot(intent)
      programme = intent.broadcast_observation
      [programme.guide_channel_id, programme.starts_at, programme.ends_at]
    end
  end
end
