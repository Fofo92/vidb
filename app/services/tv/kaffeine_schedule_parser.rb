require "json"
require "time"

module Tv
  KaffeineSchedule = Data.define(
    :key, :name, :channel, :starts_at, :duration_seconds, :repeat, :non_inactive
  )

  class KaffeineScheduleParser
    class InvalidResponse < StandardError; end

    SCHEDULES_SIGNATURE = "a(ussssib)"
    CREATED_KEY_SIGNATURE = "u"

    def schedules(output)
      parse_response(output) do |document|
        validate_signature(document, SCHEDULES_SIGNATURE)
        rows = document.fetch("data").fetch(0)
        raise InvalidResponse, "unexpected schedule list" unless rows.is_a?(Array)

        rows.map { |row| build_schedule(row) }
      end
    end

    def created_key(output)
      parse_response(output) do |document|
        validate_signature(document, CREATED_KEY_SIGNATURE)
        key = Integer(document.fetch("data").fetch(0))
        raise InvalidResponse, "invalid Kaffeine schedule key" unless key.between?(0, 4_294_967_295)

        key
      end
    end

    private

    def parse_response(output)
      document = JSON.parse(output)
      raise InvalidResponse, "invalid Kaffeine response: expected object" unless document.is_a?(Hash)

      yield document
    rescue JSON::ParserError, IndexError, TypeError, ArgumentError => e
      raise InvalidResponse, "invalid Kaffeine response: #{e.message}"
    end

    def validate_signature(document, expected)
      signature = document.fetch("type")
      return if signature == expected

      raise InvalidResponse, "unexpected D-Bus signature: #{signature.inspect}"
    end

    def build_schedule(row)
      raise InvalidResponse, "unexpected schedule entry: #{row.inspect}" unless row.is_a?(Array) && row.length == 7

      raise InvalidResponse, "invalid schedule activity flag" unless [true, false].include?(row[6])

      KaffeineSchedule.new(**schedule_attributes(row))
    end

    def schedule_attributes(row)
      key, name, channel, starts_at, duration, repeat, non_inactive = row

      {
        key: Integer(key),
        name: String(name),
        channel: String(channel),
        starts_at: Time.iso8601(String(starts_at).sub(/ZZ\z/, "Z")),
        duration_seconds: parse_duration(duration),
        repeat: Integer(repeat),
        non_inactive:
      }
    end

    def parse_duration(value)
      parts = String(value).split(":")
      raise ArgumentError, "invalid duration" unless parts.length == 3

      hours, minutes, seconds = parts.map { |part| Integer(part, 10) }
      valid = hours.between?(0, 23) && minutes.between?(0, 59) && seconds.between?(0, 59)
      raise ArgumentError, "invalid duration" unless valid

      (hours * 3600) + (minutes * 60) + seconds
    end
  end
end
