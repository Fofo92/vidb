require "test_helper"

module Tv
  class KaffeineScheduleMatcherTest < ActiveSupport::TestCase
    ATTRIBUTES = {
      name: "Le film",
      channel: "F3 Paris Ile-de-France",
      starts_at: Time.utc(2030, 1, 1, 17, 50),
      duration_seconds: 6600,
      repeat: 0
    }.freeze

    test "finds a schedule with matching attributes" do
      schedule = build_schedule(key: 619)

      assert_equal schedule, matcher([schedule]).find(ATTRIBUTES)
    end

    test "ignores differences in channel start duration or repeat" do
      schedules = [
        build_schedule(key: 620, channel: "TF1"),
        build_schedule(key: 621, starts_at: ATTRIBUTES.fetch(:starts_at) + 60),
        build_schedule(key: 622, duration_seconds: 6500),
        build_schedule(key: 623, repeat: 16)
      ]

      assert_nil matcher(schedules).find(ATTRIBUTES)
    end

    test "ignores a different title" do
      assert_nil matcher([build_schedule(key: 620, name: "Autre film")]).find(ATTRIBUTES)
    end

    test "does not confuse an inactive schedule with a different programme" do
      schedule = build_schedule(key: 619, non_inactive: false)

      assert_equal schedule, matcher([schedule]).find(ATTRIBUTES)
    end

    test "rejects multiple matching schedules rather than choosing an arbitrary key" do
      schedules = [build_schedule(key: 619), build_schedule(key: 620)]

      assert_raises(KaffeineScheduleMatcher::AmbiguousMatch) do
        matcher(schedules).find(ATTRIBUTES)
      end
    end

    private

    def matcher(schedules)
      KaffeineScheduleMatcher.new(schedules:)
    end

    def build_schedule(key:, non_inactive: false, **overrides)
      KaffeineSchedule.new(key:, **ATTRIBUTES.merge(overrides), non_inactive:)
    end
  end
end
