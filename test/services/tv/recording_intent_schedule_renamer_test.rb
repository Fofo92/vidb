require "test_helper"

module Tv
  class RecordingIntentScheduleRenamerTest < ActiveSupport::TestCase
    class FakeManager
      attr_reader :replaced

      def initialize(replacement)
        @replacement = replacement
      end

      def replace(schedule, **attributes)
        @replaced = [schedule, attributes]
        @replacement
      end
    end

    setup do
      source = GuideSource.create!(name: "xml_tv_fr", display_name: "XML TV Fr")
      channel = Channel.create!(display_name: "France 3", kaffeine_name: "F3 Paris Ile-de-France")
      guide_channel = source.guide_channels.create!(external_id: "France3.fr", channel:)
      observation = guide_channel.broadcast_observations.create!(
        fingerprint: "a" * 64, starts_at: Time.utc(2030, 1, 1, 18),
        ends_at: Time.utc(2030, 1, 1, 19, 30),
        titles: [{ "value" => "La stagiaire", "language" => "fr" }],
        episode_numbers: [{ "system" => "xmltv_ns", "value" => "10.4." }]
      )
      @intent = RecordingIntent.create!(broadcast_observation: observation)
      @attributes = RecordingIntentScheduleAttributes.new(recording_intent: @intent).call
      @original = KaffeineSchedule.new(
        key: 1049, **@attributes.merge(name: "La stagiaire"), non_inactive: false
      )
      @replacement = KaffeineSchedule.new(key: 1050, **@attributes, non_inactive: false)
      @client = Struct.new(:schedules).new([@original])
      @manager = FakeManager.new(@replacement)
    end

    test "replaces a verified vidb schedule and updates its key and name" do
      link = KaffeineScheduleLink.attach!(
        recording_intent: @intent, schedule: @original, origin: :created_by_vidb
      )

      result = renamer.call

      assert_equal @replacement, result
      assert_equal [@original, @attributes], @manager.replaced
      assert_equal 1050, link.reload.kaffeine_key
      assert_equal "La stagiaire - S11 E05", link.name
    end

    test "does nothing when the linked schedule already has the full name" do
      @client.schedules[0] = @replacement
      KaffeineScheduleLink.attach!(
        recording_intent: @intent, schedule: @replacement, origin: :created_by_vidb
      )

      assert_equal @replacement, renamer.call
      assert_nil @manager.replaced
    end

    test "uses an explicitly selected title after verifying the linked schedule" do
      KaffeineScheduleLink.attach!(
        recording_intent: @intent, schedule: @original, origin: :created_by_vidb
      )
      selected_name = "La stagiaire - S11 E05 - Le retour"
      manager = FakeManager.new(@replacement.with(name: selected_name))

      result = RecordingIntentScheduleRenamer.new(
        recording_intent: @intent, client: @client, manager:, target_name: selected_name
      ).call

      assert_equal selected_name, result.name
      assert_equal selected_name, manager.replaced.last.fetch(:name)
      assert_equal selected_name, @intent.kaffeine_schedule_link.reload.name
    end

    test "does not replace when another identical schedule already exists" do
      KaffeineScheduleLink.attach!(
        recording_intent: @intent, schedule: @original, origin: :created_by_vidb
      )
      @client.schedules << @replacement

      assert_raises(RecordingIntentScheduleRenamer::Unavailable) { renamer.call }
      assert_nil @manager.replaced
    end

    test "does not replace a schedule created outside vidb" do
      KaffeineScheduleLink.attach!(
        recording_intent: @intent, schedule: @original, origin: :preexisting
      )

      assert_raises(RecordingIntentScheduleRenamer::Unavailable) { renamer.call }
      assert_nil @manager.replaced
    end

    test "does not replace a changed linked schedule" do
      KaffeineScheduleLink.attach!(
        recording_intent: @intent, schedule: @original, origin: :created_by_vidb
      )
      @client.schedules[0] = @original.with(channel: "TF1")

      assert_raises(RecordingIntentScheduleRenamer::Unavailable) { renamer.call }
      assert_nil @manager.replaced
    end

    private

    def renamer
      RecordingIntentScheduleRenamer.new(
        recording_intent: @intent, client: @client, manager: @manager
      )
    end
  end
end
