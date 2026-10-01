require "test_helper"

module Tv
  class GuideScheduleTitleChooserTest < ActiveSupport::TestCase
    setup do
      source = GuideSource.create!(name: "xml_tv_fr", display_name: "XML TV Fr")
      channel = Channel.create!(display_name: "Arte", kaffeine_name: "Arte")
      guide_channel = source.guide_channels.create!(external_id: "Arte.fr", channel:)
      @old = observation(guide_channel, "Ancien titre", "a")
      @current = observation(guide_channel, "Titre enrichi", "b")
      attach_import(source, @old, "c", 1)
      attach_import(source, @current, "d", 2)
      @intent = RecordingIntent.create!(broadcast_observation: @old)
      link_schedule(:created_by_vidb)
    end

    test "offers the latest title to the verified renamer" do
      renamer = Minitest::Mock.new
      renamer.expect(:call, :confirmed)
      factory = lambda do |**options|
        assert_equal @intent, options.fetch(:recording_intent)
        assert_equal "Titre enrichi", options.fetch(:target_name)
        renamer
      end

      RecordingIntentScheduleRenamer.stub(:new, factory) do
        assert_equal :confirmed, chooser(@current).call
      end
      renamer.verify
    end

    test "refuses a title from an earlier import" do
      assert_raises(GuideScheduleTitleChooser::Unavailable) { chooser(@old).call }
    end

    test "refuses a changed time or channel" do
      @current.update!(starts_at: @current.starts_at + 1.minute)

      assert_raises(GuideScheduleTitleChooser::Unavailable) { chooser(@current).call }
    end

    test "refuses a schedule created outside vidb" do
      @intent.kaffeine_schedule_link.update!(origin: :preexisting)

      assert_raises(GuideScheduleTitleChooser::Unavailable) { chooser(@current).call }
    end

    private

    def chooser(observation)
      GuideScheduleTitleChooser.new(recording_intent: @intent, observation:, client: Object.new)
    end

    def observation(channel, title, fingerprint)
      channel.broadcast_observations.create!(
        fingerprint: fingerprint * 64,
        starts_at: Time.utc(2030, 1, 1, 18), ends_at: Time.utc(2030, 1, 1, 19),
        titles: [{ "value" => title, "language" => "fr" }]
      )
    end

    def attach_import(source, observation, fingerprint, minute)
      imported = source.guide_imports.create!(
        document_sha256: fingerprint * 64, document_byte_size: 100,
        status: "succeeded", started_at: Time.utc(2030, 1, 1),
        finished_at: Time.utc(2030, 1, 1, 0, minute)
      )
      imported.guide_import_observations.create!(broadcast_observation: observation)
    end

    def link_schedule(origin)
      attributes = RecordingIntentScheduleAttributes.new(recording_intent: @intent).call
      schedule = KaffeineSchedule.new(key: 123, **attributes, non_inactive: false)
      KaffeineScheduleLink.attach!(recording_intent: @intent, schedule:, origin:)
    end
  end
end
