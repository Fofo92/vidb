require "test_helper"
require "minitest/mock"

class TvRecordingIntentsControllerTest <
    ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    user = User.create!(
      email: "tv-recording@example.com",
      password: "password"
    )
    sign_in user

    @source = Tv::GuideSource.create!(
      name: "xml_tv_fr",
      display_name: "XML TV Fr"
    )
    guide_channel = @source.guide_channels.create!(
      external_id: "France2.fr"
    )
    start_time = 2.days.from_now.change(usec: 0)
    @observation = guide_channel.broadcast_observations.create!(
      fingerprint: "a" * 64,
      starts_at: start_time,
      ends_at: start_time + 90.minutes
    )
  end

  test "selects a programme and returns to the same guide view" do
    assert_difference("Tv::RecordingIntent.count", 1) do
      post tv_recording_intents_url, params: request_params
    end

    intent = Tv::RecordingIntent.find_by!(
      broadcast_observation: @observation
    )

    assert intent.status_selected?
    assert_redirected_to tv_guide_path(guide_params)
  end

  test "cancels a selection and returns to the same guide view" do
    intent = Tv::RecordingIntentSelector.new(
      broadcast_observation: @observation
    ).call

    assert_no_difference("Tv::RecordingIntent.count") do
      delete tv_recording_intent_url(intent), params: guide_params
    end

    assert intent.reload.status_cancelled?
    assert_redirected_to tv_guide_path(guide_params)
  end

  test "removes a linked Kaffeine schedule before cancelling" do
    intent = Tv::RecordingIntentSelector.new(broadcast_observation: @observation).call
    schedule = linked_schedule(intent)
    link = Tv::KaffeineScheduleLink.attach!(recording_intent: intent, schedule:, origin: :created_by_vidb)
    assert link.reload.matches?(schedule)
    client = fake_client([schedule])

    Tv::KaffeineDbus.stub(:new, client) do
      delete tv_recording_intent_url(intent), params: guide_params
    end

    assert_equal [982], client.removed
    assert intent.reload.status_cancelled?
    assert_nil intent.kaffeine_schedule_link
    assert_redirected_to tv_guide_path(guide_params)
  end

  test "keeps the intent selected when Kaffeine changed the linked schedule" do
    intent = Tv::RecordingIntentSelector.new(broadcast_observation: @observation).call
    schedule = linked_schedule(intent)
    Tv::KaffeineScheduleLink.attach!(recording_intent: intent, schedule:, origin: :created_by_vidb)
    client = fake_client([schedule.with(channel: "TF1")])

    Tv::KaffeineDbus.stub(:new, client) do
      delete tv_recording_intent_url(intent), params: guide_params
    end

    assert_empty client.removed
    assert intent.reload.status_selected?
    assert_match(/Annulation non confirmée/, flash[:alert])
  end

  private

  def linked_schedule(intent)
    Tv::KaffeineSchedule.new(
      key: 982, name: "Le film", channel: "France 2",
      starts_at: intent.capture_starts_at, duration_seconds: 6600,
      repeat: 0, non_inactive: false
    )
  end

  def fake_client(entries)
    client_class = Struct.new(:entries, :removed) do
      def schedules
        entries
      end

      def remove_schedule(key)
        removed << key
        entries.reject! { |entry| entry.key == key }
      end
    end
    client_class.new(entries, [])
  end

  def request_params
    {
      broadcast_observation_id: @observation.id
    }.merge(guide_params)
  end

  def guide_params
    {
      date: @observation.starts_at.in_time_zone("Europe/Paris").to_date.iso8601,
      guide_source_id: @source.id,
      zoom: "4",
      all_channels: "1"
    }
  end
end
