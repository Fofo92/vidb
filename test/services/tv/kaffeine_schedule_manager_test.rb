require "test_helper"

module Tv

  class KaffeineScheduleManagerTest < ActiveSupport::TestCase
    FakeClient = Data.define(:created_key, :entries) do
      def create_schedule(**_attributes)
        created_key
      end

      def schedules
        entries
      end
    end

    REQUEST = {
      name: 'TEST PROGRAMMATION',
      channel: 'TF1',
      starts_at: Time.utc(2031, 1, 1, 12),
      duration_seconds: 120,
      repeat: 0
    }.freeze

    def test_creates_and_verifies_a_schedule
      expected = schedule(key: 618)
      client = FakeClient.new(created_key: 618, entries: [expected])
      manager = KaffeineScheduleManager.new(client:)

      assert_equal expected, manager.create(**REQUEST)
    end

    def test_keeps_an_unverified_schedule
      returned = schedule(key: 618, channel: 'M6')
      client = FakeClient.new(created_key: 618, entries: [returned])
      manager = KaffeineScheduleManager.new(client:)

      error = assert_raises(
        KaffeineScheduleManager::VerificationError
      ) do
        manager.create(**REQUEST)
      end

      assert_match(/618/, error.message)
    end

    private

    def schedule(key:, **overrides)
      attributes = REQUEST.merge(overrides)

      KaffeineSchedule.new(
        key:,
        **attributes,
        non_inactive: false
      )
    end
  end
end
