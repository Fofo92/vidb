require "test_helper"

module Tv
  class KaffeineScheduleParserTest < ActiveSupport::TestCase
    test "reads a schedule and normalizes Kaffeine double Z timestamps" do
      schedule = parser.schedules(schedule_response).fetch(0)

      assert_equal 570, schedule.key
      assert_equal "À l'instinct", schedule.name
      assert_equal "France 2", schedule.channel
      assert_equal Time.utc(2026, 9, 18, 19), schedule.starts_at
      assert_equal 19_203, schedule.duration_seconds
      assert_equal 16, schedule.repeat
      assert_equal false, schedule.non_inactive
    end

    test "reads an empty schedule list" do
      assert_empty parser.schedules(JSON.generate("type" => "a(ussssib)", "data" => [[]]))
    end

    test "reads a newly created key including Kaffeine rejection value" do
      assert_equal 619, parser.created_key(JSON.generate("type" => "u", "data" => [619]))
      assert_equal 0, parser.created_key(JSON.generate("type" => "u", "data" => [0]))
    end

    test "rejects incorrect signatures" do
      error = assert_raises(KaffeineScheduleParser::InvalidResponse) do
        parser.schedules(JSON.generate("type" => "u", "data" => [[]]))
      end

      assert_match(/unexpected D-Bus signature/, error.message)
    end

    test "rejects malformed JSON and missing fields" do
      ["{", "[]", JSON.generate("type" => "u")].each do |output|
        assert_raises(KaffeineScheduleParser::InvalidResponse) { parser.created_key(output) }
      end
    end

    test "rejects malformed schedule entries and duration" do
      [
        [570],
        schedule_row.tap { |row| row[4] = "25:00:00" },
        schedule_row.tap { |row| row[6] = "false" }
      ].each do |row|
        output = JSON.generate("type" => "a(ussssib)", "data" => [[row]])
        assert_raises(KaffeineScheduleParser::InvalidResponse) { parser.schedules(output) }
      end
    end

    private

    def parser
      KaffeineScheduleParser.new
    end

    def schedule_response
      JSON.generate("type" => "a(ussssib)", "data" => [[schedule_row]])
    end

    def schedule_row
      [570, "À l'instinct", "France 2", "2026-09-18T19:00:00ZZ", "05:20:03", 16, false]
    end
  end
end
