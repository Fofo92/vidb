require "test_helper"

class TvGuidesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    user = User.create!(
      email: "test@example.com",
      password: "password"
    )
    sign_in user

    @guide_source = Tv::GuideSource.create!(
      name: "xml_tv_fr_test",
      display_name: "XML TV Fr"
    )

    @france_two = Tv::Channel.create!(
      display_name: "France 2",
      logical_number: 2
    )
  end

  test "displays the selected Paris calendar day" do
    get tv_guide_url, params: {
      date: "2026-09-18",
      guide_source_id: @guide_source.id
    }

    assert_response :success
    assert_select "h1", text: /Programmes TV/
    assert_select(
      "form[action='#{tv_guide_path}'][method='get']"
    )
    assert_select(
      "input[name='date'][value='2026-09-18']"
    )
    assert_select(
      "[data-tv-guide-day='2026-09-18']"
    )
    assert_select "[data-tv-guide-programme]", count: 0
    assert_select(
      "input[type='checkbox']" \
      "[name='all_channels']" \
      "[value='1']",
      count: 1
    )
  end

  test "groups programmes by channel with Paris times" do
    guide_import = create_successful_import
    channel = create_france_two_guide_channel
    programme = create_programme(
      guide_import, channel,
      title: "Un si grand soleil",
      starts_at: "2026-09-18T20:55:00+02:00",
      ends_at: "2026-09-18T22:30:00+02:00"
    )

    get tv_guide_url, params: { date: "2026-09-18", guide_source_id: @guide_source.id }

    assert_response :success

    assert_select(
      "[data-tv-guide-channel='France2.fr']"
    ) do
      assert_select(
        "[data-tv-guide-channel-name]",
        text: "France 2"
      )

      assert_select(
        "[data-tv-guide-programme='#{programme.id}']"
      ) do
        assert_select "[data-tv-guide-start]", text: "20:55"
        assert_select "[data-tv-guide-end]", text: "22:30"
        assert_select("[data-tv-guide-title]", text: "Un si grand soleil")
      end
    end
  end

  test "defaults to the first enabled source and the current Paris day" do
    travel_to Time.utc(2026, 9, 18, 10) do
      get tv_guide_url
    end

    assert_response :success
    assert_select "[data-tv-guide-day='2026-09-18']"
    assert_select(
      "input[name='guide_source_id']" \
      "[value='#{@guide_source.id}']"
    )
  end

  test "offers the TV guide in the main navigation" do
    get tv_guide_url
    assert_response :success
    assert_select(
      "a[href='#{tv_guide_path}']",
      text: "Programmes TV"
    )
  end

  test "explains when no enabled guide source is available" do
    @guide_source.destroy!

    get tv_guide_url
    assert_response :success
    assert_select(
      "[data-tv-guide-unavailable]",
      text: /Aucune source de programmes TV/
    )
    assert_select "form[action='#{tv_guide_path}']", count: 0
    assert_select "[data-tv-guide-programme]", count: 0
  end

  test "displays the available editorial programme metadata" do
    guide_import = create_successful_import
    channel = create_france_two_guide_channel
    programme = create_programme(
      guide_import,
      channel,
      title: "Un si grand soleil",
      starts_at: "2026-09-18T20:55:00+02:00",
      ends_at: "2026-09-18T22:30:00+02:00"
    )

    add_editorial_metadata(programme)
    get tv_guide_url, params: { date: "2026-09-18", guide_source_id: @guide_source.id }
    assert_response :success
    assert_editorial_metadata(programme)
  end

  private

  def create_france_two_guide_channel
    @guide_source.guide_channels.create!(
      external_id: "France2.fr",
      channel: @france_two,
      display_names: [metadata("France 2")]
    )
  end

  def add_editorial_metadata(programme)
    programme.update!(
      titles: [metadata("Un si grand soleil"), metadata("Chronicles of the Sun", "en")],
      subtitles: [metadata("Épisode du dimanche")], descriptions: [metadata("Résumé de l’épisode.")],
      categories: [metadata("Série dramatique")], episode_numbers: [{ "value" => "7.42.", "system" => "xmltv_ns" }]
    )
  end

  def metadata(value, language = "fr")
    { "value" => value, "language" => language }
  end

  def assert_editorial_metadata(programme)
    assert_select(
      "[data-tv-guide-programme='#{programme.id}']" \
      "[tabindex='0']"
    ) do
      editorial_expectations.each do |selector, text|
        assert_select selector, text: text
      end
    end
  end

  def editorial_expectations
    {
      "[data-tv-guide-original-title]" => /Chronicles of the Sun/,
      "[data-tv-guide-episode]" => /Saison 8.*épisode 43/i,
      "[data-tv-guide-subtitle]" => "Épisode du dimanche",
      "[data-tv-guide-category]" => "Série dramatique",
      "[data-tv-guide-secondary] " \
      "[data-tv-guide-description]" => "Résumé de l’épisode."
    }
  end

  def create_successful_import
    @guide_source.guide_imports.create!(
      document_sha256: "a" * 64,
      document_byte_size: 100,
      status: "succeeded",
      started_at: Time.utc(2026, 9, 18, 8),
      finished_at: Time.utc(2026, 9, 18, 8, 1)
    )
  end

  def create_programme(guide_import, channel, title:, starts_at:, ends_at:)
    programme = channel.broadcast_observations.create!(
      fingerprint: "b" * 64,
      starts_at: starts_at,
      ends_at: ends_at,
      titles: [{ "value" => title, "language" => "fr" }]
    )

    guide_import.guide_import_observations.create!(
      broadcast_observation: programme
    )

    programme
  end
end
