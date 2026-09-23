require "test_helper"

class TvGuidesTimelineTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    sign_in create_user
    @source = create_source
    @guide_channel = create_guide_channel
    @guide_import = create_guide_import
  end

  test "exposes programme positions on a shared daily timeline" do
    programme = create_programme(
      "2026-09-18T20:55:00+02:00",
      "2026-09-18T22:30:00+02:00"
    )

    get tv_guide_url, params: { date: "2026-09-18", guide_source_id: @source.id }

    assert_select(
      "[data-tv-guide-timeline]" \
      "[data-tv-guide-duration-minutes='1440']"
    )
    assert_select(
      "[data-tv-guide-programme='#{programme.id}']" \
      "[data-tv-guide-start-minute='1255']" \
      "[data-tv-guide-duration-minutes='95']"
    )
    assert_select "[data-tv-guide-grid]", count: 1
    assert_select "[data-tv-guide-time-axis]", count: 1
    assert_select "[data-tv-guide-time-tick]", count: 24
    assert_select(
      "[data-tv-guide-grid]" \
      "[data-tv-guide-minute-height='2']"
    )
  end

  test "accepts a detailed timeline scale" do
    create_programme(
      "2026-09-18T20:55:00+02:00",
      "2026-09-18T22:30:00+02:00"
    )

    get tv_guide_url, params: {
      date: "2026-09-18",
      guide_source_id: @source.id,
      zoom: "4"
    }

    assert_select(
      "[data-tv-guide-grid]" \
      "[data-tv-guide-minute-height='4']"
    )
  end

  test "keeps a short programme readable and interactive" do
    paris = ActiveSupport::TimeZone["Europe/Paris"]
    programme = create_programme(
      paris.local(2026, 9, 18, 6, 20),
      paris.local(2026, 9, 18, 6, 25)
    )

    get tv_guide_url(date: "2026-09-18")

    assert_response :success
    assert_select(
      "[data-tv-guide-programme='#{programme.id}']" \
      "[data-tv-guide-top-pixels='760']" \
      "[data-tv-guide-height-pixels='24']" \
      "[data-tv-guide-single-line='true']",
      count: 1
    )
    assert_select(
      "[data-tv-guide-grid]" \
      "[data-tv-guide-height-pixels='2894']",
      count: 1
    )

    assert_select(
      "[data-tv-guide-time-tick]" \
      "[data-tv-guide-minute='420']" \
      "[data-tv-guide-top-pixels='854']",
      count: 1
    )

    assert_select(
      "[data-tv-guide-channel='#{programme.guide_channel.external_id}'] " \
      "[data-tv-guide-hour-line]" \
      "[data-tv-guide-minute='420']" \
      "[data-tv-guide-top-pixels='854']",
      count: 1
    )

    assert_select(
      "[data-tv-guide-programme='#{programme.id}']",
      text: /06:20\s+[–-]\s+06:25/
    )
    assert_select(
      "[data-tv-guide-programme='#{programme.id}']" \
      "[data-tv-guide-short]",
      count: 0
    )
  end

  private

  def create_user
    User.create!(email: "timeline@example.com", password: "password")
  end

  def create_source
    Tv::GuideSource.create!(
      name: "timeline_test",
      display_name: "Guide du test temporel"
    )
  end

  def create_guide_channel
    @source.guide_channels.create!(
      external_id: "France2.fr",
      channel: create_business_channel,
      display_names: [metadata("France 2")]
    )
  end

  def create_business_channel
    Tv::Channel.create!(
      display_name: "France 2",
      logical_number: 2
    )
  end

  def create_guide_import
    @source.guide_imports.create!(
      document_sha256: "e" * 64,
      document_byte_size: 100,
      status: "succeeded",
      started_at: Time.utc(2026, 9, 18, 8),
      finished_at: Time.utc(2026, 9, 18, 8, 1)
    )
  end

  def create_programme(starts_at, ends_at)
    programme = @guide_channel.broadcast_observations.create!(
      fingerprint: "f" * 64,
      starts_at: starts_at,
      ends_at: ends_at,
      titles: [metadata("Programme du soir")]
    )

    link_programme(programme)
    programme
  end

  def link_programme(programme)
    @guide_import.guide_import_observations.create!(
      broadcast_observation: programme
    )
  end

  def metadata(value)
    { "value" => value, "language" => "fr" }
  end
end
