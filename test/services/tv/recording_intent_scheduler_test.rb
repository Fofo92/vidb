require "test_helper"

module Tv
  class RecordingIntentSchedulerTest < ActiveSupport::TestCase
    class FakeClient
      attr_reader :created

      def initialize(entries: [])
        @entries = entries
        @created = []
      end

      def schedules
        @entries
      end

      def create_schedule(**attributes)
        @created << attributes
        @entries << KaffeineSchedule.new(key: 619, **attributes, non_inactive: false)
        619
      end
    end

    setup do
      source = GuideSource.create!(name: "xml_tv_fr", display_name: "XML TV Fr")
      channel = Channel.create!(display_name: "France 3", kaffeine_name: "F3 Paris Ile-de-France")
      guide_channel = source.guide_channels.create!(external_id: "France3.fr", channel:)
      observation = guide_channel.broadcast_observations.create!(
        fingerprint: "a" * 64,
        starts_at: Time.utc(2030, 1, 1, 18),
        ends_at: Time.utc(2030, 1, 1, 19, 30),
        titles: [{ "value" => "Le film", "language" => "fr" }]
      )
      @intent = RecordingIntent.create!(broadcast_observation: observation)
    end

    test "creates and verifies a missing schedule" do
      client = FakeClient.new

      schedule = scheduler(client).call

      assert_equal 619, schedule.key
      assert_equal [expected_attributes], client.created
    end

    test "reuses an identical schedule without creating another" do
      existing = KaffeineSchedule.new(key: 618, **expected_attributes, non_inactive: false)
      client = FakeClient.new(entries: [existing])

      assert_equal existing, scheduler(client).call
      assert_empty client.created
    end

    test "refuses an ambiguous match without creating another" do
      first = KaffeineSchedule.new(key: 618, **expected_attributes, non_inactive: false)
      second = KaffeineSchedule.new(key: 619, **expected_attributes, non_inactive: false)
      client = FakeClient.new(entries: [first, second])

      assert_raises(KaffeineScheduleMatcher::AmbiguousMatch) { scheduler(client).call }
      assert_empty client.created
    end

    test "refuses a cancelled intent without creating a schedule" do
      @intent.update!(status: "cancelled")
      client = FakeClient.new

      assert_raises(RecordingIntentScheduleAttributes::Unavailable) { scheduler(client).call }
      assert_empty client.created
    end

    private

    def scheduler(client)
      RecordingIntentScheduler.new(recording_intent: @intent, client:)
    end

    def expected_attributes
      {
        name: "Le film",
        channel: "F3 Paris Ile-de-France",
        starts_at: Time.utc(2030, 1, 1, 17, 50),
        duration_seconds: 6600,
        repeat: 0
      }
    end
  end
end
