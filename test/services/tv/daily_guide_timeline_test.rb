require "test_helper"

module Tv
  class DailyGuideTimelineTest < ActiveSupport::TestCase
    test "positions programmes on a shared Paris day timeline" do
      timeline = DailyGuideTimeline.new(
        date: Date.new(2026, 9, 18),
        programmes: standard_programmes
      ).call

      assert_equal 1_440, timeline.duration_minutes
      assert_standard_positions(timeline)
      assert_standard_ticks(timeline)
    end

    test "represents a 25-hour Paris day" do
      programmes = [
        programme(
          "2026-10-25T23:30:00+01:00",
          "2026-10-26T00:30:00+01:00"
        )
      ]

      timeline = DailyGuideTimeline.new(
        date: Date.new(2026, 10, 25),
        programmes: programmes
      ).call

      assert_equal 1_500, timeline.duration_minutes
      assert_equal 1_470, timeline.items.first.start_minute
      assert_equal 30, timeline.items.first.duration_minutes

      assert_equal 25, timeline.ticks.size
      assert_equal(
        ["02:00", "02:00"],
        timeline.ticks
                .select { |tick| tick.label == "02:00" }
                .map(&:label)
      )
    end

    private

    def standard_programmes
      [
        programme("2026-09-17T23:30:00+02:00", "2026-09-18T00:30:00+02:00"),
        programme("2026-09-18T12:00:00+02:00", "2026-09-18T13:30:00+02:00"),
        programme("2026-09-18T23:30:00+02:00", "2026-09-19T00:30:00+02:00")
      ]
    end

    def assert_standard_positions(timeline)
      positions = timeline.items.map do |item|
        [item.start_minute, item.duration_minutes]
      end

      assert_equal(
        [[0, 30], [720, 90], [1_410, 30]],
        positions
      )
    end

    def assert_standard_ticks(timeline)
      assert_equal 24, timeline.ticks.size
      assert_equal(
        [0, "00:00"],
        [timeline.ticks.first.minute, timeline.ticks.first.label]
      )
      assert_equal(
        [1_380, "23:00"],
        [timeline.ticks.last.minute, timeline.ticks.last.label]
      )
    end

    def programme(starts_at, ends_at)
      BroadcastObservation.new(
        starts_at: starts_at,
        ends_at: ends_at
      )
    end
  end
end
