require "test_helper"

module Tv
  class KaffeineDbusTest < ActiveSupport::TestCase
    Status = Data.define(:exitstatus) do
      def success?
        exitstatus.zero?
      end
    end

    test "lists schedules through the builder runner and parser" do
      client, commands = client_with_responses(
        JSON.generate("type" => "a(ussssib)", "data" => [[schedule_row]])
      )

      schedule = client.schedules.fetch(0)

      assert_equal KaffeineCommandBuilder::SCHEDULES_COMMAND, commands.fetch(0)
      assert_equal 570, schedule.key
      assert_equal "France 2", schedule.channel
    end

    test "creates a schedule and returns its key" do
      client, commands = client_with_responses(JSON.generate("type" => "u", "data" => [619]))

      assert_equal 619, client.create_schedule(**schedule_attributes)
      assert_equal builder.create_schedule_command(**schedule_attributes), commands.fetch(0)
    end

    test "rejects a zero key returned by Kaffeine" do
      client, = client_with_responses(JSON.generate("type" => "u", "data" => [0]))

      assert_raises(KaffeineDbus::ScheduleRejected) do
        client.create_schedule(**schedule_attributes)
      end
    end

    test "removes a schedule with its numeric key" do
      client, commands = client_with_responses("")

      assert_nil client.remove_schedule(619)
      assert_equal builder.remove_schedule_command(619), commands.fetch(0)
    end

    test "propagates a command failure" do
      fake_runner = ->(*_arguments) { ["", "D-Bus unavailable", Status.new(exitstatus: 1)] }
      client = KaffeineDbus.new(command_runner: KaffeineCommandRunner.new(command_runner: fake_runner))

      assert_raises(KaffeineCommandRunner::CommandError) { client.schedules }
    end

    test "propagates a malformed response" do
      client, = client_with_responses("{")

      assert_raises(KaffeineScheduleParser::InvalidResponse) { client.schedules }
    end

    private

    def builder
      KaffeineCommandBuilder.new
    end

    def client_with_responses(*responses)
      commands = []
      fake_runner = lambda do |*arguments|
        commands << arguments
        [responses.shift, "", Status.new(exitstatus: 0)]
      end
      client = KaffeineDbus.new(command_runner: KaffeineCommandRunner.new(command_runner: fake_runner))

      [client, commands]
    end

    def schedule_attributes
      {
        name: "Émission du soir",
        channel: "F3 Paris Ile-de-France",
        starts_at: Time.utc(2030, 1, 1, 12),
        duration_seconds: 120,
        repeat: 0
      }
    end

    def schedule_row
      [570, "À l'instinct", "France 2", "2026-09-18T19:00:00ZZ", "05:20:03", 16, false]
    end
  end
end
