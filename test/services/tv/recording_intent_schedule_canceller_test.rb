require "test_helper"

module Tv
  class RecordingIntentScheduleCancellerTest < ActiveSupport::TestCase
    class FakeClient
      attr_reader :removed

      def initialize(entries)
        @entries = entries
        @removed = []
      end

      def schedules
        @entries
      end

      def remove_schedule(key)
        @removed << key
        @entries.reject! { |schedule| schedule.key == key }
      end
    end

    setup do
      source = GuideSource.create!(name: "xml_tv_fr", display_name: "XML TV Fr")
      guide_channel = source.guide_channels.create!(external_id: "France4.fr")
      observation = guide_channel.broadcast_observations.create!(
        fingerprint: "a" * 64,
        starts_at: Time.utc(2030, 9, 30, 21, 55),
        ends_at: Time.utc(2030, 9, 30, 23, 30)
      )
      @intent = RecordingIntent.create!(broadcast_observation: observation)
      @schedule = KaffeineSchedule.new(
        key: 982, name: "Les Faux British", channel: "France 4",
        starts_at: Time.utc(2030, 9, 30, 21, 45), duration_seconds: 6900,
        repeat: 0, non_inactive: false
      )
    end

    test "removes a managed schedule before cancelling its intent" do
      attach_schedule(:created_by_vidb)
      client = FakeClient.new([@schedule])

      assert_equal @intent, cancel(client)
      assert_equal [982], client.removed
      assert @intent.reload.status_cancelled?
      assert_nil @intent.kaffeine_schedule_link
    end

    test "cancels an adopted intent without removing a preexisting schedule" do
      attach_schedule(:preexisting)
      client = FakeClient.new([@schedule])

      cancel(client)

      assert_empty client.removed
      assert @intent.reload.status_cancelled?
      assert_nil @intent.kaffeine_schedule_link
    end

    test "refuses to remove a changed or missing managed schedule" do
      attach_schedule(:created_by_vidb)
      [[], [@schedule.with(channel: "TF1")]].each do |entries|
        client = FakeClient.new(entries)

        assert_raises(RecordingIntentScheduleCanceller::LinkedScheduleMismatch) { cancel(client) }
        assert_empty client.removed
        assert @intent.reload.status_selected?
      end
    end

    test "refuses a cancellation inside the two minute guard" do
      attach_schedule(:created_by_vidb)
      client = FakeClient.new([@schedule])
      clock = -> { @schedule.starts_at - 120 }

      assert_raises(RecordingIntentScheduleCanceller::TooLateToCancel) { cancel(client, clock:) }
      assert_empty client.removed
      assert @intent.reload.status_selected?
    end

    test "cancels an intent without a linked schedule" do
      client = FakeClient.new([])

      cancel(client)

      assert @intent.reload.status_cancelled?
      assert_empty client.removed
    end

    private

    def attach_schedule(origin)
      KaffeineScheduleLink.attach!(recording_intent: @intent, schedule: @schedule, origin:)
    end

    def cancel(client, clock: -> { Time.utc(2030, 9, 27) })
      RecordingIntentScheduleCanceller.new(recording_intent: @intent, client:, clock:).call
    end
  end
end
