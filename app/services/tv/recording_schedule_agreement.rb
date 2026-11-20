module Tv
  class RecordingScheduleAgreement
    def self.call(intent, link, schedule)
      return false unless schedule && link.matches?(schedule)

      expected = RecordingIntentScheduleAttributes.new(recording_intent: intent).call
      expected.all? { |field, value| schedule.public_send(field) == value }
    rescue RecordingIntentScheduleAttributes::Unavailable
      false
    end
  end
end
