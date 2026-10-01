require "test_helper"

class TvGuidesRecordingIntentsTest <
    ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    sign_in User.create!(
      email: "tv-guide-recording@example.com",
      password: "password"
    )

    @source = create_source
    guide_channel = create_guide_channel
    guide_import = create_successful_import
    @programme = create_programme(guide_channel, guide_import)
  end

  test "offers to select an unselected programme" do
    get tv_guide_url, params: guide_params

    assert_response :success
    assert_scroll_restoration_hook

    assert_select programme_selector("unselected") do
      assert_select(
        "form[action='#{tv_recording_intents_path}']" \
        "[method='post']"
      ) do
        assert_select(
          "input[name='broadcast_observation_id']" \
          "[value='#{@programme.id}']"
        )
        assert_select(
          "button[data-tv-guide-recording-toggle]" \
          "[aria-label*='Sélectionner']",
          count: 1
        )
      end
      assert_information_button
    end
  end

  test "uses the same episode name as the recording and Kaffeine" do
    @programme.update!(
      episode_numbers: [{ "system" => "xmltv_ns", "value" => "2.7." }],
      subtitles: [{ "value" => "Le départ", "language" => "fr" }]
    )

    get tv_guide_url, params: guide_params

    assert_select "#{programme_selector('unselected')} [data-tv-guide-title]",
                  text: "Film du soir - S03 E08 - Le départ"
  end

  test "marks a rerun only after a previous recording was verified" do
    @programme.update!(episode_numbers: [{ "system" => "xmltv_ns", "value" => "2.7." }])
    previous = @programme.guide_channel.broadcast_observations.create!(
      fingerprint: "c" * 64,
      starts_at: Time.utc(2026, 9, 25, 18),
      ends_at: Time.utc(2026, 9, 25, 19, 30),
      titles: @programme.titles,
      episode_numbers: @programme.episode_numbers
    )
    intent = Tv::RecordingIntentSelector.new(broadcast_observation: previous).call
    schedule = Tv::KaffeineSchedule.new(
      key: 970, name: "Film du soir - S03 E08", channel: "France 2",
      starts_at: intent.capture_starts_at,
      duration_seconds: (intent.capture_ends_at - intent.capture_starts_at).to_i,
      repeat: 0, non_inactive: false
    )
    Tv::KaffeineScheduleLink.attach!(recording_intent: intent, schedule:, origin: :created_by_vidb)

    get tv_guide_url, params: guide_params
    assert_select "#{programme_selector('unselected')} [data-tv-guide-previous-recording]", count: 0

    intent.update!(recording_verified_at: Time.utc(2026, 9, 26, 12))
    get tv_guide_url, params: guide_params

    assert_select "#{programme_selector('unselected')} [data-tv-guide-previous-recording]",
                  text: /Déjà enregistré/
    assert_select "#{programme_selector('unselected')} [data-tv-guide-previous-recording-detail]",
                  text: /25\/09\/2026/
    assert_select "#{programme_selector('unselected')} form[action='#{tv_recording_intents_path}']"
  end

  test "does not confuse a different episode with a verified recording" do
    @programme.update!(episode_numbers: [{ "system" => "xmltv_ns", "value" => "2.8." }])
    previous = @programme.guide_channel.broadcast_observations.create!(
      fingerprint: "c" * 64,
      starts_at: Time.utc(2026, 9, 25, 18),
      ends_at: Time.utc(2026, 9, 25, 19, 30),
      titles: @programme.titles,
      episode_numbers: [{ "system" => "xmltv_ns", "value" => "2.7." }]
    )
    Tv::RecordingIntentSelector.new(broadcast_observation: previous).call
      .update!(recording_verified_at: Time.utc(2026, 9, 26, 12))

    get tv_guide_url, params: guide_params

    assert_select "#{programme_selector('unselected')} [data-tv-guide-previous-recording]", count: 0
  end

  test "marks an episode already programmed for another day" do
    @programme.update!(episode_numbers: [{ "system" => "xmltv_ns", "value" => "3.3." }])
    other = @programme.guide_channel.broadcast_observations.create!(
      fingerprint: "d" * 64,
      starts_at: Time.utc(2026, 10, 1, 16),
      ends_at: Time.utc(2026, 10, 1, 17),
      titles: @programme.titles,
      episode_numbers: @programme.episode_numbers
    )
    intent = Tv::RecordingIntentSelector.new(broadcast_observation: other).call
    schedule = Tv::KaffeineSchedule.new(
      key: 999, name: "Film du soir - S04 E04", channel: "France 2",
      starts_at: intent.capture_starts_at,
      duration_seconds: (intent.capture_ends_at - intent.capture_starts_at).to_i,
      repeat: 0, non_inactive: false
    )
    Tv::KaffeineScheduleLink.attach!(recording_intent: intent, schedule:, origin: :created_by_vidb)

    get tv_guide_url, params: guide_params

    assert_select "#{programme_selector('unselected')} [data-tv-guide-scheduled-duplicate]",
                  text: /Épisode déjà programmé/
    assert_select "#{programme_selector('unselected')} [data-tv-guide-scheduled-duplicate-detail]",
                  text: /Kaffeine n° 999/
  end

  test "offers one click scheduling for an unselected linked channel" do
    @programme.guide_channel.channel.update!(kaffeine_name: "France 2")

    get tv_guide_url, params: guide_params

    assert_select programme_selector("unselected") do
      assert_select "button[data-tv-guide-recording-toggle]" \
                    "[aria-label*='Programmer'][aria-label*='Kaffeine']"
      assert_select "form button[data-tv-guide-information]", count: 0
    end
  end

  test "offers to cancel a selected programme" do
    intent = Tv::RecordingIntentSelector.new(
      broadcast_observation: @programme
    ).call

    get tv_guide_url, params: guide_params

    assert_response :success
    assert_selected_programme(intent)
  end

  test "offers Kaffeine scheduling from the guide when the channel is linked" do
    channel = @programme.guide_channel.channel
    channel.update!(kaffeine_name: "France 2")
    intent = Tv::RecordingIntentSelector.new(broadcast_observation: @programme).call

    get tv_guide_url, params: guide_params

    assert_select programme_selector("selected") do
      assert_select "button[data-tv-guide-recording-toggle][aria-label*='Annuler']"
    end
    assert_select "form[action='#{tv_recording_intent_schedule_path(intent)}']" do
      assert_select "input[name='return_to'][value='guide']"
      assert_select "input[name='date'][value='2026-09-27']"
      assert_select "button[type='submit'][aria-label='Programmer dans Kaffeine']",
                    text: "Kaffeine"
    end
  end

  test "shows only the Kaffeine number on a confirmed programme" do
    intent = Tv::RecordingIntentSelector.new(broadcast_observation: @programme).call
    schedule = Tv::KaffeineSchedule.new(
      key: 986,
      name: "Film du soir",
      channel: "France 2",
      starts_at: intent.capture_starts_at,
      duration_seconds: (intent.capture_ends_at - intent.capture_starts_at).to_i,
      repeat: 0,
      non_inactive: false
    )
    Tv::KaffeineScheduleLink.attach!(recording_intent: intent, schedule:, origin: :created_by_vidb)

    get tv_guide_url, params: guide_params

    assert_select "#{programme_selector('selected')} [data-tv-guide-schedule]" \
                  "[aria-label*='numéro 986']", text: /986/
    assert_equal "986", css_select("[data-tv-guide-schedule]").first.text.strip
  end

  test "shows an episode numbering alert on the replacement programme" do
    prepare_future_alert
    @programme.update!(
      titles: [{ "value" => "Meurtres à... - Saison 9", "language" => "fr" }],
      subtitles: [{ "value" => "Meurtres à Amiens", "language" => "fr" }],
      episode_numbers: [{ "system" => "xmltv_ns", "value" => "8.0." }]
    )
    Tv::RecordingIntentSelector.new(broadcast_observation: @programme).call
    current = replace_guide(episode_numbers: [{ "system" => "xmltv_ns", "value" => "8.10." }])

    get tv_guide_url, params: guide_params

    assert_response :success
    assert_select "[data-tv-guide-programme='#{current.id}'] [data-tv-guide-refresh-alert]",
                  text: /!/, count: 1
    assert_select "[data-tv-guide-programme='#{current.id}'] .tv-guide-refresh-alert-detail",
                  text: /Numérotation discordante/
    assert_select "[data-tv-guide-programme='#{current.id}'] .tv-guide-refresh-alert-detail",
                  text: /Ancien guide : Meurtres à\.\.\. - Saison 9 - S09 E01 - Meurtres à Amiens/
    assert_select "[data-tv-guide-programme='#{current.id}'] .tv-guide-refresh-alert-detail",
                  text: /Nouveau guide : Meurtres à\.\.\. - S09 E11 - Meurtres à Amiens/
  end

  test "does not warn when only the guide presentation changed" do
    prepare_future_alert
    @programme.update!(titles: [{ "value" => "MacGyver - Saison 1", "language" => "fr" }])
    Tv::RecordingIntentSelector.new(broadcast_observation: @programme).call
    replace_guide

    get tv_guide_url, params: guide_params

    assert_response :success
    assert_select "[data-tv-guide-refresh-alert]", count: 0
    assert_select "[data-tv-guide-unplaced-alerts]", count: 0
  end

  test "shows both titles when the broadcast at the selected time changed" do
    prepare_future_alert
    Tv::RecordingIntentSelector.new(broadcast_observation: @programme).call
    current = replace_guide
    current.update!(titles: [{ "value" => "Autre film", "language" => "fr" }])

    get tv_guide_url, params: guide_params

    assert_response :success
    assert_select "[data-tv-guide-programme='#{current.id}'] .tv-guide-refresh-alert-detail",
                  text: /Ancien guide : Film du soir.*Nouveau guide : Autre film/m
  end

  test "shows a separate warning when the old time slot disappeared" do
    prepare_future_alert
    Tv::RecordingIntentSelector.new(broadcast_observation: @programme).call
    replace_guide(starts_at: @programme.starts_at + 2.hours)

    get tv_guide_url, params: guide_params

    assert_response :success
    assert_select "[data-tv-guide-unplaced-alerts]", text: /aucune plage aux mêmes horaires/
  end

  private

  def prepare_future_alert
    @alert_date = "2030-09-27"
    @programme.update!(
      starts_at: Time.utc(2030, 9, 27, 18),
      ends_at: Time.utc(2030, 9, 27, 19, 30)
    )
  end

  def replace_guide(episode_numbers: @programme.episode_numbers, starts_at: @programme.starts_at)
    current = replacement_programme(episode_numbers, starts_at)
    replacement_import.guide_import_observations.create!(broadcast_observation: current)
    current
  end

  def replacement_import
    @source.guide_imports.create!(
      document_sha256: "d" * 64, document_byte_size: 100,
      status: "succeeded", started_at: Time.utc(2030, 9, 27),
      finished_at: Time.utc(2030, 9, 27, 0, 1)
    )
  end

  def replacement_programme(episode_numbers, starts_at)
    @programme.guide_channel.broadcast_observations.create!(
      fingerprint: "e" * 64, starts_at:, ends_at: starts_at + 90.minutes,
      titles: [{ "value" => @programme.titles.first.fetch("value").sub(/ - Saison \d+\z/, ""),
                 "language" => "fr" }],
      subtitles: @programme.subtitles, episode_numbers:
    )
  end

  def assert_selected_programme(intent)
    assert_select(selected_programme_selector, count: 1)

    assert_select programme_selector("selected") do
      assert_cancellation_form(intent)
      assert_information_button
      assert_select("form[action='#{tv_recording_intents_path}']", count: 0)
    end
  end

  def selected_programme_selector
    "#{programme_selector('selected')}" \
      ".tv-guide-programme--recording-selected"
  end

  def assert_cancellation_form(intent)
    assert_select(
      "form[action='#{tv_recording_intent_path(intent)}']" \
      "[method='post']"
    ) do
      assert_select "input[name='_method'][value='delete']"
      assert_select(
        "button[data-tv-guide-recording-toggle]",
        count: 1
      )
    end
  end

  def assert_information_button
    assert_select(
      "button[data-tv-guide-information][type='button']" \
      "[aria-expanded='false']",
      text: "i",
      count: 1
    )
  end

  def assert_scroll_restoration_hook
    assert_select(
      "[data-tv-guide-scroll]" \
      "[data-controller~='tv-guide-scroll']" \
      "[data-action*='submit->tv-guide-scroll#remember']",
      count: 1
    )
  end

  def programme_selector(status)
    "[data-tv-guide-programme='#{@programme.id}']" \
      "[data-tv-guide-recording-status='#{status}']"
  end

  def guide_params
    {
      date: @alert_date || "2026-09-27",
      guide_source_id: @source.id,
      zoom: "4",
      all_channels: "1"
    }
  end

  def create_source
    Tv::GuideSource.create!(
      name: "xml_tv_fr",
      display_name: "XML TV Fr"
    )
  end

  def create_guide_channel
    channel = Tv::Channel.create!(
      display_name: "France 2",
      logical_number: 2
    )

    @source.guide_channels.create!(
      external_id: "France2.fr",
      channel: channel
    )
  end

  def create_successful_import
    @source.guide_imports.create!(
      document_sha256: "a" * 64,
      document_byte_size: 100,
      status: "succeeded",
      started_at: Time.utc(2026, 9, 26, 8),
      finished_at: Time.utc(2026, 9, 26, 8, 1)
    )
  end

  def create_programme(guide_channel, guide_import)
    programme = guide_channel.broadcast_observations.create!(
      fingerprint: "b" * 64,
      starts_at: Time.utc(2026, 9, 27, 18),
      ends_at: Time.utc(2026, 9, 27, 19, 30),
      titles: [{ "value" => "Film du soir", "language" => "fr" }]
    )

    guide_import.guide_import_observations.create!(
      broadcast_observation: programme
    )

    programme
  end
end
