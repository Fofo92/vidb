require "test_helper"

module Tv
  class RecordingIntentScheduleAttributesTest < ActiveSupport::TestCase
    setup do
      source = GuideSource.create!(name: "xml_tv_fr", display_name: "XML TV Fr")
      @channel = Channel.create!(display_name: "France 3", kaffeine_name: "F3 Paris Ile-de-France")
      guide_channel = source.guide_channels.create!(external_id: "France3.fr", channel: @channel)
      observation = guide_channel.broadcast_observations.create!(
        fingerprint: "a" * 64,
        starts_at: Time.utc(2030, 1, 1, 18),
        ends_at: Time.utc(2030, 1, 1, 19, 30),
        titles: [{ "value" => "Film", "language" => "en" }, { "value" => "Le film", "language" => "fr" }]
      )
      @intent = RecordingIntent.create!(broadcast_observation: observation)
    end

    test "maps the selected intent and its effective margins to Kaffeine attributes" do
      assert_equal(
        {
          name: "Le film",
          channel: "F3 Paris Ile-de-France",
          starts_at: Time.utc(2030, 1, 1, 17, 50),
          duration_seconds: 6600,
          repeat: 0
        },
        attributes
      )
    end

    test "includes the season and episode in a new Kaffeine schedule" do
      @intent.broadcast_observation.update!(
        episode_numbers: [{ "system" => "xmltv_ns", "value" => "10.4." }]
      )

      assert_equal "Le film - S11 E05", attributes.fetch(:name)
      assert_equal "Le film", RecordingIntentScheduleAttributes.new(recording_intent: @intent).base_name
    end

    test "adds the episode subtitle when available" do
      @intent.broadcast_observation.update!(
        episode_numbers: [{ "system" => "xmltv_ns", "value" => "10.4." }],
        subtitles: [{ "value" => "Un nouveau départ", "language" => "fr" }]
      )

      assert_equal "Le film - S11 E05 - Un nouveau départ", attributes.fetch(:name)
    end

    test "rejects a cancelled intent" do
      @intent.update!(status: "cancelled")

      assert_raises(RecordingIntentScheduleAttributes::Unavailable) { attributes }
    end

    test "rejects a channel without a Kaffeine mapping" do
      @channel.update!(kaffeine_name: nil)

      assert_raises(RecordingIntentScheduleAttributes::Unavailable) { attributes }
    end

    test "rejects a programme without a title" do
      @intent.broadcast_observation.update!(titles: [])

      assert_raises(RecordingIntentScheduleAttributes::Unavailable) { attributes }
    end

    test "rejects a capture longer than Kaffeine accepts" do
      @intent.update!(programme_ends_at: @intent.programme_starts_at + 24.hours)

      assert_raises(RecordingIntentScheduleAttributes::Unavailable) { attributes }
    end

    private

    def attributes
      RecordingIntentScheduleAttributes.new(recording_intent: @intent).call
    end
  end
end
