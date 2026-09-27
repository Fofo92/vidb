module Tv
  class KaffeineDbus
    class ScheduleRejected < StandardError; end

    def initialize(
      command_builder: KaffeineCommandBuilder.new,
      command_runner: KaffeineCommandRunner.new,
      schedule_parser: KaffeineScheduleParser.new
    )
      @command_builder = command_builder
      @command_runner = command_runner
      @schedule_parser = schedule_parser
    end

    def schedules
      output = @command_runner.call(@command_builder.schedules_command)
      @schedule_parser.schedules(output)
    end

    def create_schedule(name:, channel:, starts_at:, duration_seconds:, repeat:)
      command = @command_builder.create_schedule_command(
        name:, channel:, starts_at:, duration_seconds:, repeat:
      )
      output = @command_runner.call(command)
      key = @schedule_parser.created_key(output)

      raise ScheduleRejected, "Kaffeine rejected the schedule" if key.zero?

      key
    end

    def remove_schedule(key)
      @command_runner.call(@command_builder.remove_schedule_command(key))
      nil
    end
  end
end
