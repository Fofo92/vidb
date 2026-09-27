require "test_helper"

module Tv
  class KaffeineCommandRunnerTest < ActiveSupport::TestCase
    Status = Data.define(:exitstatus) do
      def success?
        exitstatus.zero?
      end
    end

    test "passes every argument separately and returns stdout" do
      command = KaffeineCommandBuilder.new.create_schedule_command(
        name: "Émission du soir",
        channel: "F3 Paris Ile-de-France",
        starts_at: Time.utc(2030, 1, 1, 12),
        duration_seconds: 120,
        repeat: 0
      )
      calls = []
      fake_runner = lambda do |*arguments|
        calls << arguments
        ['{"type":"u","data":[619]}', "", Status.new(exitstatus: 0)]
      end

      output = KaffeineCommandRunner.new(command_runner: fake_runner).call(command)

      assert_equal '{"type":"u","data":[619]}', output
      assert_equal [command], calls
    end

    test "reports stderr when the command fails" do
      fake_runner = ->(*_arguments) { ["", "D-Bus unavailable\n", Status.new(exitstatus: 1)] }

      error = assert_raises(KaffeineCommandRunner::CommandError) do
        KaffeineCommandRunner.new(command_runner: fake_runner).call(["busctl"])
      end

      assert_equal "D-Bus unavailable", error.message
    end

    test "reports exit status when stderr is empty" do
      fake_runner = ->(*_arguments) { ["", "", Status.new(exitstatus: 7)] }

      error = assert_raises(KaffeineCommandRunner::CommandError) do
        KaffeineCommandRunner.new(command_runner: fake_runner).call(["busctl"])
      end

      assert_equal "busctl exited with status 7", error.message
    end
  end
end
