module Tv
  class KaffeineScheduleMatcher
    class AmbiguousMatch < StandardError; end

    ATTRIBUTES = %i[name channel starts_at duration_seconds repeat].freeze

    def initialize(schedules:)
      @schedules = schedules
    end

    def find(attributes)
      matches = @schedules.select do |schedule|
        ATTRIBUTES.all? do |attribute|
          schedule.public_send(attribute) == attributes.fetch(attribute)
        end
      end

      raise AmbiguousMatch, "several Kaffeine schedules match the recording intent" if matches.length > 1

      matches.first
    end
  end
end
