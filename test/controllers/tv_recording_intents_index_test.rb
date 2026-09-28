require "test_helper"

class TvRecordingIntentsIndexTest <
    ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    sign_in User.create!(
      email: "recording-intents-index@example.com",
      password: "password"
    )
    @source = Tv::GuideSource.create!(
      name: "xml_tv_fr",
      display_name: "XML TV Fr"
    )
    @guide_channel = @source.guide_channels.create!(
      external_id: "France2.fr"
    )
  end

  test "lists only selected intents in chronological order" do
    later_intent = create_intent(
      hour: 21,
      fingerprint: "b" * 64
    )
    earlier_intent = create_intent(
      hour: 18,
      fingerprint: "a" * 64
    )
    cancelled_intent = create_intent(
      hour: 19,
      fingerprint: "c" * 64
    )
    cancelled_intent.update!(status: "cancelled")

    get tv_recording_intents_url

    assert_response :success
    assert_equal(
      [earlier_intent.id.to_s, later_intent.id.to_s],
      rendered_intent_ids
    )
    assert_select(
      recording_intent_selector(cancelled_intent),
      count: 0
    )
  end

  test "displays programme and capture details" do
    intent = create_intent(
      hour: 18,
      fingerprint: "d" * 64
    )

    get tv_recording_intents_url

    assert_response :success
    assert_recording_details(intent)
    assert_select "a[href='#{tv_kaffeine_schedules_path}']", text: "Voir toutes les programmations Kaffeine"
  end

  test "shows season and episode when XMLTV supplies them" do
    intent = create_intent(hour: 18, fingerprint: "9" * 64)
    intent.broadcast_observation.update!(
      episode_numbers: [{ "system" => "xmltv_ns", "value" => "2.7." }]
    )

    get tv_recording_intents_url

    assert_select "#{recording_intent_selector(intent)} [data-recording-title]",
                  text: "Programme de 18 h - S03 E08"
  end

  test "allows confirming a completed capture and removing the confirmation" do
    intent = create_intent(hour: 18, fingerprint: "7" * 64)
    schedule = Tv::KaffeineSchedule.new(
      key: 982, name: "Programme de 18 h", channel: "France 2",
      starts_at: intent.capture_starts_at,
      duration_seconds: (intent.capture_ends_at - intent.capture_starts_at).to_i,
      repeat: 0, non_inactive: false
    )
    Tv::KaffeineScheduleLink.attach!(recording_intent: intent, schedule:, origin: :created_by_vidb)

    travel_to paris.local(2026, 9, 28, 12) do
      get tv_recording_intents_url
      assert_select "form[action='#{tv_recording_intent_recording_confirmation_path(intent)}'] button",
                    text: "J’ai vérifié le fichier"

      post tv_recording_intent_recording_confirmation_url(intent)
      assert_predicate intent.reload, :recording_verified_at?

      delete tv_recording_intent_recording_confirmation_url(intent)
      assert_nil intent.reload.recording_verified_at
    end
  end

  test "rejects confirmation without a link even after the capture has finished" do
    intent = create_intent(hour: 18, fingerprint: "8" * 64)

    travel_to paris.local(2026, 9, 28, 12) do
      post tv_recording_intent_recording_confirmation_url(intent)
    end

    assert_nil intent.reload.recording_verified_at
    assert_redirected_to tv_recording_intents_url
  end

  test "uses the episode subtitle in the recording name" do
    intent = create_intent(hour: 18, fingerprint: "5" * 64)
    intent.broadcast_observation.update!(
      episode_numbers: [{ "system" => "xmltv_ns", "value" => "2.7." }],
      subtitles: [{ "value" => "Le départ", "language" => "fr" }]
    )

    get tv_recording_intents_url

    assert_select "#{recording_intent_selector(intent)} [data-recording-title]",
                  text: "Programme de 18 h - S03 E08 - Le départ"
  end

  test "cancels a selection and returns to the summary" do
    intent = create_intent(
      hour: 18,
      fingerprint: "e" * 64
    )

    delete tv_recording_intent_url(intent), params: {
      return_to: "index"
    }

    assert_redirected_to tv_recording_intents_url
    assert_predicate intent.reload, :status_cancelled?

    follow_redirect!

    assert_response :success
    assert_select recording_intent_selector(intent), count: 0
  end

  test "groups selections by Paris calendar day" do
    first_intent = create_intent(
      day: 27,
      hour: 23,
      fingerprint: "f" * 64
    )
    second_intent = create_intent(
      day: 28,
      hour: 18,
      fingerprint: "0" * 64
    )

    get tv_recording_intents_url

    assert_response :success
    assert_recording_day("2026-09-27", "27 septembre 2026", first_intent)
    assert_recording_day("2026-09-28", "28 septembre 2026", second_intent)
  end

  test "presents each day as a compact recording table" do
    intent = create_intent(
      hour: 18,
      fingerprint: "1" * 64
    )

    get tv_recording_intents_url

    assert_response :success
    assert_select "[data-recording-intents-table]" do
      assert_equal(
        ["Chaîne", "Nom", "Programme", "Capture"],
        recording_table_headers
      )
      assert_select recording_intent_selector(intent), count: 1
    end
  end

  test "offers explicit scheduling then displays the linked Kaffeine key" do
    channel = Tv::Channel.create!(display_name: "France 2", kaffeine_name: "France 2")
    @guide_channel.update!(channel:)
    intent = create_intent(hour: 18, fingerprint: "2" * 64)

    get tv_recording_intents_url

    assert_select "form[action='#{tv_recording_intent_schedule_path(intent)}'] button",
                  text: "Programmer dans Kaffeine"

    attributes = Tv::RecordingIntentScheduleAttributes.new(recording_intent: intent).call
    schedule = Tv::KaffeineSchedule.new(key: 982, **attributes, non_inactive: false)
    Tv::KaffeineScheduleLink.attach!(recording_intent: intent, schedule:, origin: :created_by_vidb)

    get tv_recording_intents_url

    assert_select "[data-kaffeine-schedule]", text: /Programmée \(n° 982\)/
    assert_select "form[action='#{tv_recording_intent_schedule_path(intent)}']", count: 0
  end

  test "explains a linked Kaffeine title without an XMLTV episode" do
    channel = Tv::Channel.create!(display_name: "France 2", kaffeine_name: "France 2")
    @guide_channel.update!(channel:)
    intent = create_intent(hour: 18, fingerprint: "4" * 64)
    intent.broadcast_observation.update!(
      episode_numbers: [{ "system" => "xmltv_ns", "value" => "10.4." }]
    )
    attributes = Tv::RecordingIntentScheduleAttributes.new(recording_intent: intent).call
    schedule = Tv::KaffeineSchedule.new(
      key: 982, **attributes.merge(name: "Programme de 18 h"), non_inactive: false
    )
    Tv::KaffeineScheduleLink.attach!(recording_intent: intent, schedule:, origin: :preexisting)

    get tv_recording_intents_url

    assert_select "#{recording_intent_selector(intent)} [data-recording-title]",
                  text: "Programme de 18 h - S11 E05"
    assert_select "#{recording_intent_selector(intent)} [data-kaffeine-schedule]",
                  text: /Programmée \(n° 982\)/
    assert_select "#{recording_intent_selector(intent)} [data-kaffeine-name]",
                  text: /Nom Kaffeine à la liaison : Programme de 18 h/
  end

  test "explains when a channel has no Kaffeine mapping" do
    intent = create_intent(hour: 18, fingerprint: "3" * 64)

    get tv_recording_intents_url

    assert_select "#{recording_intent_selector(intent)} [data-kaffeine-schedule]",
                  text: "Chaîne non reliée"
    assert_select "form[action='#{tv_recording_intent_schedule_path(intent)}']", count: 0
  end

  private

  def recording_table_headers
    css_select(
      "[data-recording-intents-table] thead th"
    ).map { |element| element.text.strip }
  end

  def create_intent(hour:, fingerprint:, day: 27, guide_channel: @guide_channel)
    observation = guide_channel.broadcast_observations.create!(
      titles: [{ "value" => "Programme de #{hour} h", "language" => "fr" }],
      starts_at: paris.local(2026, 9, day, hour),
      ends_at: paris.local(2026, 9, day, hour + 1),
      fingerprint: fingerprint
    )

    Tv::RecordingIntentSelector.new(
      broadcast_observation: observation
    ).call
  end

  def rendered_intent_ids
    css_select("[data-recording-intent]").map do |element|
      element["data-recording-intent"]
    end
  end

  def recording_intent_selector(intent)
    "[data-recording-intent='#{intent.id}']"
  end

  def paris
    ActiveSupport::TimeZone["Europe/Paris"]
  end

  def assert_recording_details(intent)
    assert_select recording_intent_selector(intent) do
      assert_programme_details
      assert_capture_details
      assert_cancellation_form(intent)
    end
  end

  def assert_programme_details
    assert_select("[data-recording-channel]", text: "France2.fr")
    assert_select("[data-recording-title]", text: "Programme de 18 h")
    assert_select("[data-programme-window]", text: /18:00\s+[–-]\s+19:00/)
  end

  def assert_capture_details
    assert_select("[data-capture-window]", text: /17:50\s+[–-]\s+19:10/)
  end

  def assert_cancellation_form(intent)
    assert_select cancellation_form_selector(intent) do
      assert_select "input[name='_method'][value='delete']"
      assert_select "input[name='return_to'][value='index']"
      assert_select "button[type='submit']", text: "Annuler"
    end
  end

  def cancellation_form_selector(intent)
    "form[action='#{tv_recording_intent_path(intent)}']" \
      "[method='post']"
  end

  def assert_recording_day(date, heading, intent)
    assert_select(
      "[data-recording-day='#{date}']"
    ) do
      assert_select "h2", text: heading
      assert_select recording_intent_selector(intent), count: 1
    end
  end
end
