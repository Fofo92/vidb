require "test_helper"

module Tv
  class RecordingIntentTest < ActiveSupport::TestCase
    PADDING_FIELDS = %i[
      requested_padding_before_seconds
      requested_padding_after_seconds
      effective_padding_before_seconds
      effective_padding_after_seconds
    ].freeze

    setup do
      source = GuideSource.create!(
        name: "xml_tv_fr",
        display_name: "XML TV Fr"
      )
      guide_channel = source.guide_channels.create!(
        external_id: "France2.fr"
      )
      @programme_starts_at = Time.utc(2026, 9, 24, 18, 0)
      @programme_ends_at = Time.utc(2026, 9, 24, 19, 30)
      @observation = guide_channel.broadcast_observations.create!(
        fingerprint: "a" * 64,
        starts_at: @programme_starts_at,
        ends_at: @programme_ends_at
      )
    end

    test "requires its broadcast observation" do
      intent = build_intent(broadcast_observation: nil)

      assert_not intent.valid?
      assert intent.errors[:broadcast_observation].any?
    end

    test "snapshots the programme times when it is created" do
      intent = build_intent
      intent.save!

      assert_equal @programme_starts_at, intent.programme_starts_at
      assert_equal @programme_ends_at, intent.programme_ends_at

      @observation.update!(
        starts_at: @programme_starts_at + 1.hour,
        ends_at: @programme_ends_at + 1.hour
      )

      intent.reload

      assert_equal @programme_starts_at, intent.programme_starts_at
      assert_equal @programme_ends_at, intent.programme_ends_at
    end

    test "defaults requested and effective padding to ten minutes" do
      intent = build_intent

      assert_equal 600, intent.requested_padding_before_seconds
      assert_equal 600, intent.requested_padding_after_seconds
      assert_equal 600, intent.effective_padding_before_seconds
      assert_equal 600, intent.effective_padding_after_seconds
    end

    test "calculates its effective capture interval" do
      intent = build_intent(
        effective_padding_before_seconds: 300,
        effective_padding_after_seconds: 900
      )
      intent.save!

      assert_equal(
        @programme_starts_at - 5.minutes,
        intent.capture_starts_at
      )
      assert_equal(
        @programme_ends_at + 15.minutes,
        intent.capture_ends_at
      )
    end

    test "requires nonnegative requested and effective padding" do
      PADDING_FIELDS.each do |field|
        [nil, -1].each do |value|
          intent = build_intent(field => value)

          assert_not intent.valid?
          assert intent.errors[field].any?
        end

        assert build_intent(field => 0).valid?
      end
    end

    test "requires the programme end to follow its start" do
      intent = build_intent(
        programme_starts_at: @programme_starts_at,
        programme_ends_at: @programme_starts_at
      )

      assert_not intent.valid?
      assert intent.errors[:programme_ends_at].any?
    end

    test "defaults to selected" do
      intent = build_intent

      assert intent.status_selected?
    end

    test "accepts the supported states" do
      %w[selected cancelled].each do |status|
        intent = build_intent(status: status)

        assert intent.valid?
        assert intent.public_send("status_#{status}?")
      end
    end

    test "rejects an unsupported state" do
      assert_raises(ArgumentError) do
        build_intent(status: "unknown")
      end
    end

    test "allows only one intent per broadcast observation" do
      build_intent.save!
      duplicate = build_intent

      assert_not duplicate.valid?
      assert duplicate.errors[:broadcast_observation].any?
    end

    test "is exposed from its broadcast observation" do
      intent = build_intent
      intent.save!

      assert_equal intent, @observation.reload.recording_intent
    end

    test "protects its broadcast observation from deletion" do
      build_intent.save!

      assert_not @observation.destroy
      assert @observation.persisted?
      assert @observation.errors[:base].any?
    end

    private

    def build_intent(attributes = {})
      RecordingIntent.new(
        {
          broadcast_observation: @observation
        }.merge(attributes)
      )
    end
  end
end
