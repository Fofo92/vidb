require "test_helper"

module Tv

  class KaffeineScheduleReplacementTest < ActiveSupport::TestCase
    class FakeClient
      attr_reader :events

      def initialize(schedule_lists:)
        @schedule_lists = schedule_lists
        @events = []
      end

      def create_schedule(**_attributes)
        @events << :create
        619
      end

      def schedules
        @events << :schedules
        @schedule_lists.shift
      end

      def remove_schedule(key)
        @events << [:remove, key]
        nil
      end
    end

    OLD_REQUEST = {
      name: 'ANCIENNE PROGRAMMATION',
      channel: 'TF1',
      starts_at: Time.utc(2031, 1, 1, 12),
      duration_seconds: 120,
      repeat: 0
    }.freeze

    NEW_REQUEST = {
      name: 'NOUVELLE PROGRAMMATION',
      channel: 'TF1',
      starts_at: Time.utc(2031, 1, 1, 12, 15),
      duration_seconds: 180,
      repeat: 0
    }.freeze

    def test_verifies_the_new_schedule_before_removing_the_old_one
      old_schedule = schedule(key: 618, attributes: OLD_REQUEST)
      new_schedule = schedule(key: 619, attributes: NEW_REQUEST)
      client = fake_client(old_schedule, new_schedule)
      manager = KaffeineScheduleManager.new(client:)

      assert_equal new_schedule, manager.replace(old_schedule, **NEW_REQUEST)
      assert_equal expected_events, client.events
    end

    def test_refuses_replacement_inside_the_safety_window
      old_schedule = schedule(key: 618, attributes: OLD_REQUEST)
      client = FakeClient.new(schedule_lists: [])
      manager = manager_at_safety_window(client)

      assert_raises(KaffeineScheduleManager::TooLateToReplace) do
        manager.replace(old_schedule, **NEW_REQUEST)
      end

      assert_empty client.events
    end

    private

    def fake_client(old_schedule, new_schedule)
      FakeClient.new(
        schedule_lists: [
          [old_schedule, new_schedule],
          [old_schedule, new_schedule],
          [new_schedule]
        ]
      )
    end

    def manager_at_safety_window(client)
      KaffeineScheduleManager.new(
        client:,
        clock: -> { Time.utc(2031, 1, 1, 11, 58) }
      )
    end

    def schedule(key:, attributes:)
      KaffeineSchedule.new(
        key:,
        **attributes,
        non_inactive: false
      )
    end

    def expected_events
      [
        :create,
        :schedules,
        :schedules,
        [:remove, 618],
        :schedules
      ]
    end
  end
end
