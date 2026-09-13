require "test_helper"

module Tv
  class XmltvCoverageTest < ActiveSupport::TestCase
    test "reports coverage and gaps separately for each channel" do
      programmes = [
        programme("France2.fr", at(10), at(11)),
        programme("France2.fr", at(12), at(13)),
        programme("France2.fr", at(12, 30), at(14)),
        programme("France3.fr", at(9), at(10))
      ]

      coverage = XmltvCoverage.new(programmes).call

      france_two = coverage.fetch("France2.fr")

      assert_equal 3, france_two.programme_count
      assert_equal at(10), france_two.starts_at
      assert_equal at(14), france_two.ends_at
      assert_equal 1, france_two.gaps.size

      gap = france_two.gaps.first

      assert_equal at(11), gap.starts_at
      assert_equal at(12), gap.ends_at
      assert_equal 3600, gap.duration_seconds

      france_three = coverage.fetch("France3.fr")

      assert_equal 1, france_three.programme_count
      assert_equal at(9), france_three.starts_at
      assert_equal at(10), france_three.ends_at
      assert_empty france_three.gaps
    end

    private

    def programme(channel_id, starts_at, ends_at)
      XmltvProgramme.new(
        channel_id: channel_id,
        starts_at: starts_at,
        ends_at: ends_at,
        titles: [],
        subtitles: [],
        descriptions: [],
        categories: [],
        episode_numbers: []
      )
    end

    def at(hour, minute = 0)
      Time.new(2026, 9, 13, hour, minute, 0, "+02:00")
    end
  end
end
