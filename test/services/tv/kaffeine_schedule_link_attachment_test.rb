require "test_helper"

module Tv
  class KaffeineScheduleLinkAttachmentTest < ActiveSupport::TestCase
    setup do
      source = GuideSource.create!(name: "xml_tv_fr", display_name: "XML TV Fr")
      @channel = source.guide_channels.create!(external_id: "CSTAR.fr")
      @now = Time.utc(2030, 10, 6, 12)
      @old_intent = intent("a", Time.utc(2030, 10, 1, 12))
      @new_intent = intent("b", Time.utc(2030, 10, 6, 19))
      @old_schedule = schedule(@old_intent, "NCIS")
      @new_schedule = schedule(@new_intent, "Hollywoo")
      @old_link = KaffeineScheduleLink.attach!(
        recording_intent: @old_intent, schedule: @old_schedule, origin: :created_by_vidb
      )
    end

    test "retires a finished owner without losing its history" do
      link = attach

      assert_equal 1400, link.kaffeine_key
      assert_equal @now, @old_link.reload.retired_at
      assert_equal "NCIS", @old_link.name
      assert_equal @old_link, @old_intent.reload.kaffeine_schedule_link
      travel_to(@now) { assert @old_intent.recording_confirmable? }
      assert_not @old_link.matches?(@new_schedule)
      assert_not @old_link.matches?(@old_schedule)
      assert_equal [link.id], KaffeineScheduleLink.active.where(kaffeine_key: 1400).pluck(:id)
    end

    test "refuses a key owned by a future recording" do
      @old_link.update!(starts_at: @now + 3600)

      assert_raises(ActiveRecord::RecordInvalid) { attach }
      assert_nil @old_link.reload.retired_at
      assert_nil @new_intent.reload.kaffeine_schedule_link
    end

    test "refuses a repeating historical owner" do
      @old_link.update!(repeat_mask: 1)

      assert_raises(ActiveRecord::RecordInvalid) { attach }
      assert_nil @old_link.reload.retired_at
    end

    test "checks the intent capture end as well as the stored schedule" do
      @old_intent.update!(programme_ends_at: @now + 3600)

      assert_raises(ActiveRecord::RecordInvalid) { attach }
      assert_nil @old_link.reload.retired_at
    end

    test "does not retire an identical schedule" do
      assert_raises(ActiveRecord::RecordInvalid) { attach(schedule: @old_schedule) }
      assert_nil @old_link.reload.retired_at
    end

    test "rolls back retirement when the new link cannot be saved" do
      invalid = @new_schedule.with(name: "")

      assert_raises(ActiveRecord::RecordInvalid) { attach(schedule: invalid) }
      assert_nil @old_link.reload.retired_at
      assert_equal 1, KaffeineScheduleLink.where(kaffeine_key: 1400).count
    end

    private

    def intent(fingerprint, starts_at)
      observation = @channel.broadcast_observations.create!(
        fingerprint: fingerprint * 64, starts_at:, ends_at: starts_at + 3600
      )
      RecordingIntent.create!(broadcast_observation: observation)
    end

    def schedule(intent, name)
      KaffeineSchedule.new(
        key: 1400, name:, channel: "CSTAR", starts_at: intent.capture_starts_at,
        duration_seconds: (intent.capture_ends_at - intent.capture_starts_at).to_i,
        repeat: 0, non_inactive: false
      )
    end

    def attach(schedule: @new_schedule)
      KaffeineScheduleLinkAttachment.new(
        recording_intent: @new_intent, schedule:, origin: :preexisting, clock: -> { @now }
      ).call
    end
  end
end
