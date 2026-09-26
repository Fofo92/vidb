module Tv
  class RecordingIntentSelector
    def initialize(broadcast_observation:)
      @broadcast_observation = broadcast_observation
    end

    def call
      intent = RecordingIntent.find_or_create_by!(
        broadcast_observation: @broadcast_observation
      )

      intent.update!(status: "selected") if intent.status_cancelled?
      intent
    end
  end
end
