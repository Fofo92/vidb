require "test_helper"

module Tv
  class RecordingIntentSelectorTest < ActiveSupport::TestCase
    setup do
      source = GuideSource.create!(
        name: "xml_tv_fr",
        display_name: "XML TV Fr"
      )
      guide_channel = source.guide_channels.create!(
        external_id: "France2.fr"
      )
      @observation = guide_channel.broadcast_observations.create!(
        fingerprint: "a" * 64,
        starts_at: Time.utc(2026, 9, 27, 18, 0),
        ends_at: Time.utc(2026, 9, 27, 19, 30)
      )
    end

    test "creates a selected intent for the observation" do
      intent = nil

      assert_difference("RecordingIntent.count", 1) do
        intent = select_observation
      end

      assert_equal @observation, intent.broadcast_observation
      assert intent.status_selected?
    end

    test "returns the existing selected intent without duplication" do
      first_intent = select_observation
      repeated_intent = nil

      assert_no_difference("RecordingIntent.count") do
        repeated_intent = select_observation
      end

      assert_equal first_intent, repeated_intent
    end

    test "reactivates a cancelled intent without changing its snapshot" do
      intent = select_observation
      original_starts_at = intent.programme_starts_at
      original_ends_at = intent.programme_ends_at
      intent.update!(status: "cancelled")

      @observation.update!(
        starts_at: @observation.starts_at + 1.hour,
        ends_at: @observation.ends_at + 1.hour
      )

      reactivated_intent = nil

      assert_no_difference("RecordingIntent.count") do
        reactivated_intent = select_observation
      end

      assert_equal intent, reactivated_intent
      assert reactivated_intent.status_selected?
      assert_equal original_starts_at, reactivated_intent.programme_starts_at
      assert_equal original_ends_at, reactivated_intent.programme_ends_at
    end

    private

    def select_observation
      RecordingIntentSelector.new(
        broadcast_observation: @observation
      ).call
    end
  end
end
