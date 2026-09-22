require "test_helper"

class TvGuidesChannelOrderingTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    user = User.create!(
      email: "channel-ordering@example.com",
      password: "password"
    )
    sign_in user

    @guide_source = Tv::GuideSource.create!(
      name: "channel_ordering_test",
      display_name: "Guide du test de tri"
    )
    @guide_import = @guide_source.guide_imports.create!(
      document_sha256: "d" * 64,
      document_byte_size: 100,
      status: "succeeded",
      started_at: Time.utc(2026, 9, 18, 8),
      finished_at: Time.utc(2026, 9, 18, 8, 1)
    )
  end

  test "orders mapped channels by their logical number" do
    create_channel_programme(
      "Arte.fr", "Arte", 7,
      "2026-09-18T10:00:00+02:00", "b" * 64
    )
    create_channel_programme(
      "France2.fr", "France 2", 2,
      "2026-09-18T11:00:00+02:00", "c" * 64
    )

    get tv_guide_url, params: {
      date: "2026-09-18",
      guide_source_id: @guide_source.id
    }

    assert_equal %w[France2.fr Arte.fr], displayed_channel_ids
  end

  test "shows only mapped and enabled business channels" do
    create_channel_programme(
      "TF1.fr", "TF1", 1,
      "2026-09-18T10:00:00+02:00", "b" * 64
    )
    disabled_channel = create_channel_programme(
      "France2.fr", "France 2", 2,
      "2026-09-18T11:00:00+02:00", "c" * 64
    )
    disabled_channel.channel.update!(enabled: false)
    create_unmapped_channel_programme

    get tv_guide_url, params: {
      date: "2026-09-18",
      guide_source_id: @guide_source.id
    }

    assert_equal ["TF1.fr"], displayed_channel_ids
  end

  private

  def create_channel_programme(
    external_id, display_name, logical_number, starts_at, fingerprint
  )
    channel = create_channel(
      external_id, display_name, logical_number
    )
    observation = create_observation(
      channel, display_name, starts_at, fingerprint
    )

    link_observation(observation)
    channel
  end

  def create_unmapped_channel_programme
    channel = @guide_source.guide_channels.create!(
      external_id: "CanalPlus.fr", display_names: [{ "value" => "Canal+", "language" => "fr" }]
    )
    observation = create_observation(
      channel,
      "Programme Canal+",
      "2026-09-18T12:00:00+02:00",
      "d" * 64
    )

    link_observation(observation)
  end

  def link_observation(observation)
    @guide_import.guide_import_observations.create!(
      broadcast_observation: observation
    )
  end

  def create_channel(external_id, display_name, logical_number)
    business_channel = Tv::Channel.create!(
      display_name: display_name,
      logical_number: logical_number
    )

    @guide_source.guide_channels.create!(
      external_id: external_id,
      channel: business_channel,
      display_names: [{ "value" => display_name, "language" => "fr" }]
    )
  end

  def create_observation(channel, title, starts_at, fingerprint)
    channel.broadcast_observations.create!(
      fingerprint: fingerprint,
      starts_at: starts_at,
      ends_at: Time.iso8601(starts_at) + 1.hour,
      titles: [{ "value" => title, "language" => "fr" }]
    )
  end

  def displayed_channel_ids
    css_select("[data-tv-guide-channel]").map do |element|
      element["data-tv-guide-channel"]
    end
  end
end
