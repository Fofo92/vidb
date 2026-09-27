require "time"

module Tv
  class KaffeineCommandBuilder
    COMMAND_PREFIX = [
      "busctl", "--user", "--json=short", "call",
      "org.kde.kaffeine", "/Television",
      "org.freedesktop.MediaPlayer"
    ].freeze

    SCHEDULES_COMMAND = [*COMMAND_PREFIX, "ListProgramSchedule"].freeze
    CREATE_COMMAND = [*COMMAND_PREFIX, "ScheduleProgram", "ssssi"].freeze
    REMOVE_COMMAND = [*COMMAND_PREFIX, "RemoveProgram", "u"].freeze

    def schedules_command
      [*command_prefix, "ListProgramSchedule"]
    end

    def create_schedule_command(name:, channel:, starts_at:, duration_seconds:, repeat:)
      duration = validated_duration(duration_seconds)
      repeat_mask = validated_repeat(repeat)

      [
        *command_prefix, "ScheduleProgram", "ssssi",
        String(name),
        String(channel),
        starts_at.to_time.utc.iso8601,
        format_duration(duration),
        repeat_mask.to_s
      ]
    end

    def remove_schedule_command(key)
      key = Integer(key)
      message = "key must be between 1 and 4294967295"
      raise ArgumentError, message unless key.between?(1, 4_294_967_295)

      [*command_prefix, "RemoveProgram", "u", key.to_s]
    end

    private

    def command_prefix
      return COMMAND_PREFIX unless ENV["VIDB_KAFFEINE_BRIDGE"] == "1"

      user = ENV.fetch("VIDB_KAFFEINE_USER")
      raise ArgumentError, "invalid Kaffeine session user" unless user.match?(/\A[a-z_][a-z0-9_-]*\z/)

      ["sudo", "-n", "-u", user, "/usr/local/libexec/vidb-kaffeine-busctl"]
    end

    def validated_duration(value)
      duration = Integer(value)
      message = "duration_seconds must be between 1 and 86399"
      raise ArgumentError, message unless duration.between?(1, 86_399)

      duration
    end

    def validated_repeat(value)
      repeat = Integer(value)
      message = "repeat must be between 0 and 127"
      raise ArgumentError, message unless repeat.between?(0, 127)

      repeat
    end

    def format_duration(duration_seconds)
      hours, remainder = duration_seconds.divmod(3600)
      minutes, seconds = remainder.divmod(60)

      format(
        "%<hours>02d:%<minutes>02d:%<seconds>02d",
        hours:, minutes:, seconds:
      )
    end
  end
end
