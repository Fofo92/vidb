require "test_helper"

module Tv
  class KaffeineScheduleLinkTest < ActiveSupport::TestCase
    setup do
      source = GuideSource.create!(name: "xml_tv_fr", display_name: "XML TV Fr")
      guide_channel = source.guide_channels.create!(external_id: "France4.fr")
      observation = guide_channel.broadcast_observations.create!(
        fingerprint: "a" * 64,
        starts_at: Time.utc(2026, 9, 30, 21, 55),
        ends_at: Time.utc(2026, 9, 30, 23, 30)
      )
      @intent = RecordingIntent.create!(broadcast_observation: observation)
      @schedule = KaffeineSchedule.new(
        key: 982,
        name: "Les Faux British",
        channel: "France 4",
        starts_at: Time.utc(2026, 9, 30, 21, 45),
        duration_seconds: 6900,
        repeat: 0,
        non_inactive: false
      )
    end

    test "stores the verified schedule identity and its origin" do
      link = attach_schedule

      assert_equal link, @intent.reload.kaffeine_schedule_link
      assert link.origin_created_by_vidb?
      assert link.matches?(@schedule)
    end

    test "does not mistake a changed Kaffeine entry for the linked schedule" do
      link = attach_schedule
      changed = @schedule.with(channel: "TF1")

      assert_not link.matches?(changed)
    end

    test "refuses to link another key to the same intent" do
      attach_schedule
      another = @schedule.with(key: 983)

      assert_raises(ActiveRecord::RecordInvalid) do
        KaffeineScheduleLink.attach!(recording_intent: @intent, schedule: another, origin: :preexisting)
      end
    end

    private

    def attach_schedule
      KaffeineScheduleLink.attach!(recording_intent: @intent, schedule: @schedule, origin: :created_by_vidb)
    end
  end
end
