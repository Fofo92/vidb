require "test_helper"

module Tv
  class RecordingSchedulePlanTest < ActiveSupport::TestCase
    class FakeClient
      attr_reader :reads

      def initialize(entries)
        @entries = entries
        @reads = 0
      end

      def schedules
        @reads += 1
        @entries
      end

      def create_schedule(**)
        raise "plan must not create a Kaffeine schedule"
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

    test "returns a plan ready for a future scheduling operation" do
      client = FakeClient.new([])

      result = RecordingSchedulePlan.new(recording_intent: @intent, client:).call

      assert_not result.already_scheduled?
      assert_nil result.existing_schedule
      assert_equal "F3 Paris Ile-de-France", result.attributes.fetch(:channel)
      assert_equal 1, client.reads
    end

    test "reports a matching existing Kaffeine schedule" do
      attributes = RecordingIntentScheduleAttributes.new(recording_intent: @intent).call
      schedule = KaffeineSchedule.new(key: 619, **attributes, non_inactive: false)
      client = FakeClient.new([schedule])

      result = RecordingSchedulePlan.new(recording_intent: @intent, client:).call

      assert result.already_scheduled?
      assert_equal schedule, result.existing_schedule
      assert_equal attributes, result.attributes
      assert_equal 1, client.reads
    end

    test "recognizes a preexisting schedule named with the title alone" do
      @intent.broadcast_observation.update!(
        episode_numbers: [{ "system" => "xmltv_ns", "value" => "10.4." }]
      )
      attributes = RecordingIntentScheduleAttributes.new(recording_intent: @intent).call
      legacy = KaffeineSchedule.new(key: 1049, **attributes.merge(name: "Le film"), non_inactive: false)
      client = FakeClient.new([legacy])

      result = RecordingSchedulePlan.new(recording_intent: @intent, client:).call

      assert_equal legacy, result.existing_schedule
      assert_equal "Le film — Saison 11, épisode 5", result.attributes.fetch(:name)
      assert_equal 1, client.reads
    end
  end
end
