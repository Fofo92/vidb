require "test_helper"

class TvGuidesControlsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    sign_in User.create!(
      email: "tv-guide-controls@example.com",
      password: "password"
    )

    @source = Tv::GuideSource.create!(
      name: "xml_tv_fr",
      display_name: "XML TV Fr"
    )
  end

  test "updates the guide automatically when a display option changes" do
    get tv_guide_url, params: guide_params

    assert_response :success
    assert_select auto_submit_form_selector do
      assert_date_control
      assert_zoom_controls
      assert_channel_controls
    end
  end

  test "shows the long date and preserves guide options when moving between days" do
    get tv_guide_url, params: guide_params.merge(zoom: "2", all_channels: "1")

    assert_response :success
    assert_select "[data-tv-guide-long-date][datetime='2026-09-27']", text: /Dimanche 27 septembre 2026/
    assert_select "[data-controller='tv-guide-date'] button[data-action='tv-guide-date#open']",
                  text: /Dimanche 27 septembre 2026/
    assert_select "[data-controller='tv-guide-date'] input[data-tv-guide-date-target='input'][type='date']"
    assert_select "a[data-tv-guide-previous-day][href*='date=2026-09-26'][href*='zoom=2'][href*='all_channels=1']"
    assert_select "a[data-tv-guide-next-day][href*='date=2026-09-28'][href*='zoom=2'][href*='all_channels=1']"
  end

  test "shows the latest scheduled recording date beside the guide update" do
    @source.guide_imports.create!(
      document_sha256: "a" * 64, document_byte_size: 100,
      status: "succeeded", started_at: Time.utc(2026, 9, 26),
      finished_at: Time.utc(2026, 9, 26, 12)
    )
    schedule_recording

    get tv_guide_url, params: guide_params

    assert_response :success
    assert_select ".tv-guide-toolbar [data-tv-guide-last-import]", text: /26\/09\/2026/
    assert_select ".tv-guide-toolbar [data-tv-guide-last-scheduled]",
                  text: /avec un dernier enregistrement programmé pour le Lundi 30 septembre 2030 à 20:00/
  end

  private

  def schedule_recording
    observation = future_observation
    intent = Tv::RecordingIntentSelector.new(broadcast_observation: observation).call
    schedule = Tv::KaffeineSchedule.new(
      key: 986, name: "Un film", channel: "France 2",
      starts_at: intent.capture_starts_at,
      duration_seconds: (intent.capture_ends_at - intent.capture_starts_at).to_i,
      repeat: 0, non_inactive: false
    )
    Tv::KaffeineScheduleLink.attach!(recording_intent: intent, schedule:, origin: :created_by_vidb)
  end

  def future_observation
    channel = Tv::Channel.create!(display_name: "France 2", logical_number: 2)
    guide_channel = @source.guide_channels.create!(external_id: "France2.fr", channel:)
    guide_channel.broadcast_observations.create!(
      fingerprint: "b" * 64,
      starts_at: Time.utc(2030, 9, 30, 18), ends_at: Time.utc(2030, 9, 30, 19),
      titles: [{ "value" => "Un film", "language" => "fr" }]
    )
  end

  def guide_params
    {
      date: "2026-09-27",
      guide_source_id: @source.id
    }
  end

  def auto_submit_form_selector
    "form[action='#{tv_guide_path}']" \
      "[method='get']" \
      "[data-controller~='auto-submit']" \
      "[data-action*='change->auto-submit#submit']"
  end

  def assert_date_control
    assert_select(
      "input[type='date'][name='date'][value='2026-09-27']"
    )
  end

  def assert_zoom_controls
    assert_select(
      "input[type='radio'][name='zoom']",
      count: 3
    )
    assert_select(
      "input[type='radio'][name='zoom'][value='1'][checked]",
      count: 1
    )
  end

  def assert_channel_controls
    assert_select("input[type='checkbox'][name='all_channels']", count: 1)
    assert_select(
      "a[href='#{edit_tv_channel_preferences_path}']",
      text: "Gérer mes chaînes favorites"
    )
    assert_select("input[type='submit'], button[type='submit']", count: 0)
  end
end
