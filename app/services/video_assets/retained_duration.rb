# frozen_string_literal: true

module VideoAssets
  class RetainedDuration
    MINUTES = /\A(\d+)\s*(?:['’′]|min(?:utes?)?|mn)(?:\s*(\d{1,2})\s*(?:["”″]|s)?)?\z/
    HOURS = /\A(\d+)\s*h\s*(\d{1,2})?\z/
    MAX_SECONDS = 86_400

    def self.parse(value)
      text = value.to_s.strip
      match = text.match(MINUTES)
      return bounded((match[1].to_i * 60) + match[2].to_i) if match && match[2].to_i < 60

      match = text.match(HOURS)
      return unless match && match[2].to_i < 60

      bounded((match[1].to_i * 3600) + (match[2].to_i * 60))
    end

    def self.from_form(minutes:, seconds:)
      return if minutes.blank? && seconds.blank?

      minute_value = Integer(minutes.presence || '0', 10)
      second_value = Integer(seconds.presence || '0', 10)
      total = bounded((minute_value * 60) + second_value)
      raise ArgumentError, 'Durée conservée invalide' unless minute_value >= 0 && second_value.between?(0, 59) && total

      total
    end

    def self.bounded(seconds)
      seconds if seconds.positive? && seconds <= MAX_SECONDS
    end
    private_class_method :bounded
  end
end
