module Tv
  class RecordingIntentScheduler
    def initialize(recording_intent:, client:, manager: nil)
      @recording_intent = recording_intent
      @client = client
      @manager = manager || KaffeineScheduleManager.new(client:)
    end

    def call
      plan = RecordingSchedulePlan.new(recording_intent: @recording_intent, client: @client).call
      return plan.existing_schedule if plan.already_scheduled?

      @manager.create(**plan.attributes)
    end
  end
end
