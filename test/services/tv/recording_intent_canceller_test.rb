require "test_helper"

module Tv
  class RecordingIntentCancellerTest < ActiveSupport::TestCase
    setup do
      source = GuideSource.create!(
        name: "xml_tv_fr",
        display_name: "XML TV Fr"
      )
      guide_channel = source.guide_channels.create!(
        external_id: "France2.fr"
      )
      observation = guide_channel.broadcast_observations.create!(
        fingerprint: "a" * 64,
        starts_at: Time.utc(2026, 9, 27, 18, 0),
        ends_at: Time.utc(2026, 9, 27, 19, 30)
      )
      @intent = RecordingIntentSelector.new(
        broadcast_observation: observation
      ).call
    end

    test "cancels a selected intent without deleting it" do
      cancelled_intent = nil

      assert_no_difference("RecordingIntent.count") do
        cancelled_intent = cancel_intent
      end

      assert_equal @intent, cancelled_intent
      assert cancelled_intent.status_cancelled?
      assert cancelled_intent.persisted?
    end

    test "does not rewrite an already cancelled intent" do
      cancel_intent
      original_updated_at = @intent.updated_at

      travel 1.second do
        cancelled_intent = cancel_intent

        assert_equal original_updated_at, cancelled_intent.updated_at
        assert cancelled_intent.status_cancelled?
      end
    end

    test "does not cancel an intent linked to a Kaffeine schedule" do
      schedule = KaffeineSchedule.new(
        key: 982, name: "Le film", channel: "France 2",
        starts_at: @intent.capture_starts_at, duration_seconds: 6600,
        repeat: 0, non_inactive: false
      )
      KaffeineScheduleLink.attach!(recording_intent: @intent, schedule:, origin: :created_by_vidb)

      assert_raises(RecordingIntentCanceller::ScheduledInKaffeine) { cancel_intent }
      assert @intent.reload.status_selected?
      assert_equal 982, @intent.kaffeine_schedule_link.kaffeine_key
    end

    private

    def cancel_intent
      RecordingIntentCanceller.new(
        recording_intent: @intent
      ).call
    end
  end
end
