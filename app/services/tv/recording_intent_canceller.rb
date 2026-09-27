module Tv
  class RecordingIntentCanceller
    class ScheduledInKaffeine < StandardError; end

    def initialize(recording_intent:)
      @recording_intent = recording_intent
    end

    def call
      raise ScheduledInKaffeine, "Kaffeine schedule must be removed first" if @recording_intent.kaffeine_schedule_link

      @recording_intent.update!(status: "cancelled")
      @recording_intent
    end
  end
end
