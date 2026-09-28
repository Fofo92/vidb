module Tv
  class RecordingIntentScheduler
    class LinkedScheduleMismatch < StandardError; end

    ERRORS = [
      RecordingIntentScheduleAttributes::Unavailable,
      KaffeineScheduleMatcher::AmbiguousMatch,
      LinkedScheduleMismatch,
      KaffeineScheduleManager::Error,
      KaffeineCommandRunner::CommandError,
      KaffeineScheduleParser::InvalidResponse,
      KaffeineScheduleLock::Busy,
      ActiveRecord::RecordInvalid
    ].freeze

    def initialize(recording_intent:, client:, manager: nil, lock: KaffeineScheduleLock.new)
      @recording_intent = recording_intent
      @client = client
      @manager = manager || KaffeineScheduleManager.new(client:)
      @lock = lock
    end

    def call
      @lock.synchronize do
        attributes = RecordingIntentScheduleAttributes.new(recording_intent: @recording_intent).call
        link = KaffeineScheduleLink.find_by(recording_intent_id: @recording_intent.id)

        link ? verified_link(link, attributes) : create_or_adopt
      end
    end

    private

    def verified_link(link, attributes)
      schedule = @client.schedules.find { |entry| entry.key == link.kaffeine_key }
      expected = attributes.merge(name: link.name)
      matches_intent = schedule && KaffeineScheduleMatcher.new(schedules: [schedule]).find(expected)
      return schedule if schedule && link.matches?(schedule) && matches_intent

      raise LinkedScheduleMismatch, "linked Kaffeine schedule #{link.kaffeine_key} is missing or changed"
    end

    def create_or_adopt
      plan = RecordingSchedulePlan.new(recording_intent: @recording_intent, client: @client).call
      if plan.already_scheduled?
        schedule = plan.existing_schedule
        origin = :preexisting
      else
        schedule = @manager.create(**plan.attributes)
        origin = :created_by_vidb
      end

      KaffeineScheduleLink.attach!(recording_intent: @recording_intent, schedule:, origin:)
      schedule
    end
  end
end
