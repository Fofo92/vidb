module Tv
  class GuideSchedulingRisks
    def initialize(client: KaffeineDbus.new)
      @client = client
    end

    def call(programmes)
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      @schedules = @client.schedules
      risks = programmes.to_h { |programme| [programme.id, risk(programme)] }
      { available: true, risks:, elapsed_ms: elapsed_ms(started) }
    rescue KaffeineCommandRunner::CommandError, KaffeineScheduleParser::InvalidResponse => e
      Rails.logger.warn("Guide capacity preview unavailable: #{e.class}: #{e.message}")
      { available: false, risks: {}, message: "Kaffeine inaccessible : capacité non vérifiée." }
    end

    private

    def risk(programme)
      attributes = attributes_for(programme)
      inspect_capacity(attributes)
    rescue MultiplexCapacityGuard::Warning => e
      level = e.message.start_with?("conflit de multiplex") ? "conflict" : "unknown"
      warning(level, e.message, attributes)
    rescue RecordingIntentScheduleAttributes::Unavailable => e
      { level: "unknown", message: "Capacité non vérifiable : #{e.message}", details: [] }
    end

    def inspect_capacity(attributes)
      MultiplexCapacityGuard.new(schedules: @schedules, attributes:).check!
      if repeating?(attributes)
        return warning("unknown", "Programmation répétitive : capacité non vérifiable.", attributes)
      end

      nil
    end

    def attributes_for(programme)
      intent = programme.recording_intent&.dup || RecordingIntent.new(
        broadcast_observation: programme, programme_starts_at: programme.starts_at,
        programme_ends_at: programme.ends_at
      )
      intent.broadcast_observation = programme
      intent.status = "selected"
      RecordingIntentScheduleAttributes.new(recording_intent: intent).call
    end

    def warning(level, message, attributes)
      details = overlapping(attributes).map do |entry|
        "#{entry.channel} : #{entry.name} (#{time_label(entry.starts_at)} – " \
          "#{time_label(entry.starts_at + entry.duration_seconds.seconds)})"
      end
      { level:, message:, details: }
    end

    def overlapping(attributes)
      ends_at = attributes.fetch(:starts_at) + attributes.fetch(:duration_seconds).seconds
      @schedules.select do |entry|
        entry.starts_at < ends_at && entry.starts_at + entry.duration_seconds.seconds > attributes.fetch(:starts_at)
      end
    end

    def repeating?(attributes)
      ends_at = attributes.fetch(:starts_at) + attributes.fetch(:duration_seconds).seconds
      @schedules.any? { |entry| entry.repeat != 0 && entry.starts_at < ends_at }
    end

    def time_label(time)
      time.in_time_zone("Europe/Paris").strftime("%d/%m %H:%M")
    end

    def elapsed_ms(started)
      ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round(1)
    end
  end
end
