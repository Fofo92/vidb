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
      builder = RecordingIntentScheduleAttributes.new(recording_intent: @recording_intent)
      attributes = builder.call
      matcher = KaffeineScheduleMatcher.new(schedules: @client.schedules)
      existing = matcher.find(attributes)
      if !existing && attributes[:name] != builder.base_name
        existing = matcher.find(attributes.merge(name: builder.base_name))
      end

      Result.new(attributes:, existing_schedule: existing)
    end
  end
end
