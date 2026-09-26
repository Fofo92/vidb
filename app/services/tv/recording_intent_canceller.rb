module Tv
  class RecordingIntentCanceller
    def initialize(recording_intent:)
      @recording_intent = recording_intent
    end

    def call
      @recording_intent.update!(status: "cancelled")
      @recording_intent
    end
  end
end
