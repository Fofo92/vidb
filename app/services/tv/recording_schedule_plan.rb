module Tv
  class RecordingSchedulePlan
    Result = Data.define(:attributes, :existing_schedule) do
      def already_scheduled?
        !existing_schedule.nil?
      end
    end

    def initialize(recording_intent:, client:)
      @recording_intent = recording_intent
      @client = client
    end

    def call
      attributes = RecordingIntentScheduleAttributes.new(recording_intent: @recording_intent).call
      existing = KaffeineScheduleMatcher.new(schedules: @client.schedules).find(attributes)

      Result.new(attributes:, existing_schedule: existing)
    end
  end
end
