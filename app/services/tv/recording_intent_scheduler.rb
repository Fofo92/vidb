module Tv
  class RecordingIntentScheduler
    def initialize(recording_intent:, client:, manager: nil, lock: KaffeineScheduleLock.new)
      @recording_intent = recording_intent
      @client = client
      @manager = manager || KaffeineScheduleManager.new(client:)
      @lock = lock
    end

    def call
      @lock.synchronize do
        plan = RecordingSchedulePlan.new(recording_intent: @recording_intent, client: @client).call
        if plan.already_scheduled?
          plan.existing_schedule
        else
          @manager.create(**plan.attributes)
        end
      end
    end
  end
end
