module Tv
  class RecordingIntentScheduleRenamer
    class Unavailable < StandardError; end

    def initialize(recording_intent:, client:, manager: nil, lock: KaffeineScheduleLock.new, target_name: nil)
      @recording_intent = recording_intent
      @client = client
      @manager = manager || KaffeineScheduleManager.new(client:)
      @lock = lock
      @target_name = target_name
    end

    def call
      @lock.synchronize do
        link = managed_link
        attributes = RecordingIntentScheduleAttributes.new(recording_intent: @recording_intent).call
        attributes = attributes.merge(name: @target_name) if @target_name
        schedule = verified_schedule(link, attributes)
        return schedule if schedule.name == attributes.fetch(:name)

        replace_and_link(link, schedule, attributes)
      end
    end

    private

    def managed_link
      link = KaffeineScheduleLink.find_by(recording_intent_id: @recording_intent.id)
      raise Unavailable, "schedule was not created by vidb" unless link&.origin_created_by_vidb?

      link
    end

    def verified_schedule(link, attributes)
      schedules = @client.schedules
      schedule = schedules.find { |entry| entry.key == link.kaffeine_key }
      expected = attributes.merge(name: link.name)
      match = schedule && KaffeineScheduleMatcher.new(schedules: [schedule]).find(expected)
      raise Unavailable, "linked schedule is missing or changed" unless match && link.matches?(schedule)
      if another_schedule?(schedules, schedule, attributes)
        raise Unavailable, "a schedule with the new name already exists"
      end

      schedule
    end

    def another_schedule?(schedules, original, attributes)
      schedules.any? do |entry|
        entry.key != original.key && KaffeineScheduleMatcher::ATTRIBUTES.all? do |field|
          entry.public_send(field) == attributes.fetch(field)
        end
      end
    end

    def replace_and_link(link, schedule, attributes)
      replacement = @manager.replace(schedule, **attributes)
      KaffeineScheduleLinkAttachment.new(
        recording_intent: @recording_intent, schedule: replacement, origin: link.origin, link:
      ).call
      replacement
    end
  end
end
