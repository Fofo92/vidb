require "test_helper"

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
    @observation = guide_channel.broadcast_observations.create!(
      fingerprint: "a" * 64,
      starts_at: Time.utc(2026, 9, 27, 18, 0),
      ends_at: Time.utc(2026, 9, 27, 19, 30)
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

  test "does not claim to cancel a Kaffeine schedule that remains active" do
    intent = Tv::RecordingIntentSelector.new(broadcast_observation: @observation).call
    schedule = Tv::KaffeineSchedule.new(
      key: 982, name: "Le film", channel: "France 2",
      starts_at: intent.capture_starts_at, duration_seconds: 6600,
      repeat: 0, non_inactive: false
    )
    Tv::KaffeineScheduleLink.attach!(recording_intent: intent, schedule:, origin: :created_by_vidb)

    delete tv_recording_intent_url(intent), params: guide_params

    assert intent.reload.status_selected?
    assert_redirected_to tv_guide_path(guide_params)
    assert_match(/Kaffeine/, flash[:alert])
  end

  private

  def request_params
    {
      broadcast_observation_id: @observation.id
    }.merge(guide_params)
  end

  def guide_params
    {
      date: "2026-09-27",
      guide_source_id: @source.id,
      zoom: "4",
      all_channels: "1"
    }
  end
end
