require "test_helper"

module Tv
  class DailyGuideProjectionTest < ActiveSupport::TestCase
    test "expands consecutive one-minute programmes on a shared scale" do
      projection = DailyGuideProjection.new(
        duration_minutes: 1_440,
        programme_ranges: [
          [360, 361],
          [361, 362]
        ],
        pixels_per_minute: 4,
        minimum_programme_height: 24
      )

      assert_equal 1_440, projection.position_for(360)
      assert_equal 1_464, projection.position_for(361)
      assert_equal 1_488, projection.position_for(362)

      assert_equal 24, projection.height_between(360, 361)
      assert_equal 24, projection.height_between(361, 362)
    end

    test "keeps the normal scale when a programme is already tall enough" do
      projection = DailyGuideProjection.new(
        duration_minutes: 1_440,
        programme_ranges: [[360, 370]],
        pixels_per_minute: 4,
        minimum_programme_height: 24
      )

      assert_equal 1_440, projection.position_for(360)
      assert_equal 1_480, projection.position_for(370)
      assert_equal 40, projection.height_between(360, 370)
    end
  end
end
