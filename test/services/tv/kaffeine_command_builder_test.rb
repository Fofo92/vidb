require "test_helper"

module Tv
  class KaffeineCommandBuilderTest < ActiveSupport::TestCase
    test "builds the list command" do
      assert_equal [
        "busctl", "--user", "--json=short", "call",
        "org.kde.kaffeine", "/Television", "org.freedesktop.MediaPlayer",
        "ListProgramSchedule"
      ], builder.schedules_command
    end

    test "builds a schedule command with UTC time and duration" do
      assert_equal [
        "busctl", "--user", "--json=short", "call",
        "org.kde.kaffeine", "/Television", "org.freedesktop.MediaPlayer",
        "ScheduleProgram", "ssssi", "Émission du soir", "F3 Paris Ile-de-France",
        "2030-01-01T11:00:00Z", "01:30:05", "127"
      ], builder.create_schedule_command(
        name: "Émission du soir",
        channel: "F3 Paris Ile-de-France",
        starts_at: Time.new(2030, 1, 1, 12, 0, 0, "+01:00"),
        duration_seconds: 5405,
        repeat: 127
      )
    end

    test "builds a removal command" do
      assert_equal [
        "busctl", "--user", "--json=short", "call",
        "org.kde.kaffeine", "/Television", "org.freedesktop.MediaPlayer",
        "RemoveProgram", "u", "619"
      ], builder.remove_schedule_command(619)
    end

    test "rejects duration outside one day" do
      [0, -1, 86_400].each do |duration|
        assert_raises(ArgumentError) { create_command(duration_seconds: duration) }
      end
    end

    test "rejects invalid repeat masks" do
      [-1, 128].each do |repeat|
        assert_raises(ArgumentError) { create_command(repeat:) }
      end
    end

    test "rejects invalid removal keys" do
      [0, -1, 4_294_967_296].each do |key|
        assert_raises(ArgumentError) { builder.remove_schedule_command(key) }
      end
    end

    private

    def builder
      KaffeineCommandBuilder.new
    end

    def create_command(duration_seconds: 120, repeat: 0)
      builder.create_schedule_command(
        name: "Test",
        channel: "TF1",
        starts_at: Time.utc(2030, 1, 1, 12),
        duration_seconds:,
        repeat:
      )
    end
  end
end
