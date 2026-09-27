require "test_helper"

module Tv

  class KaffeineScheduleRemovalTest < ActiveSupport::TestCase
    class FakeRemovalClient
      attr_reader :removed_key

      def initialize(before:, after:)
        @schedule_lists = [before, after]
      end

      def schedules
        @schedule_lists.shift
      end

      def remove_schedule(key)
        @removed_key = key
        nil
      end
    end

    REQUEST = {
      name: 'TEST PROGRAMMATION',
      channel: 'TF1',
      starts_at: Time.utc(2031, 1, 1, 12),
      duration_seconds: 120,
      repeat: 0
    }.freeze

    def test_verifies_removal_before_and_after_call
      client, expected = removal_client

      assert_nil manager(client).remove(expected)
      assert_equal 618, client.removed_key
    end

    def test_refuses_to_remove_a_different_schedule
      returned = schedule(channel: 'M6')
      client, expected = removal_client(before: [returned])

      assert_raises(manager_error) { manager(client).remove(expected) }
      assert_nil client.removed_key
    end

    def test_reports_a_schedule_still_present_after_removal
      expected = schedule
      client, = removal_client(before: [expected], after: [expected])

      assert_raises(manager_error) { manager(client).remove(expected) }
      assert_equal 618, client.removed_key
    end

    private

    def removal_client(before: nil, after: [])
      expected = schedule
      before ||= [expected]

      [FakeRemovalClient.new(before:, after:), expected]
    end

    def manager(client)
      KaffeineScheduleManager.new(client:)
    end

    def manager_error
      KaffeineScheduleManager::VerificationError
    end

    def schedule(**overrides)
      attributes = REQUEST.merge(overrides)

      KaffeineSchedule.new(
        key: 618,
        **attributes,
        non_inactive: false
      )
    end
  end
end
