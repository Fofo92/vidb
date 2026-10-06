require "test_helper"

class TvGuidesMultiplexLoadTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    sign_in User.create!(email: "multiplex@example.com", password: "password")
    @source = Tv::GuideSource.create!(name: "multiplex_guide", display_name: "Guide multiplex")
    @import = @source.guide_imports.create!(
      document_sha256: "b" * 64, document_byte_size: 100, status: "succeeded",
      started_at: Time.utc(2030, 1, 1, 8), finished_at: Time.utc(2030, 1, 1, 8, 1)
    )
    @sequence = 0
  end

  test "renders selected multiplexes including a hidden channel and an old observation" do
    programme("TF1", 1)
    hidden = programme("M6", 6, favorite: false, imported: false)
    Tv::RecordingIntent.create!(broadcast_observation: hidden)
    selected = programme("France 2", 2)
    Tv::RecordingIntent.create!(broadcast_observation: selected)

    get tv_guide_url, params: { guide_source_id: @source.id, date: "2030-01-01" }

    assert_response :success
    assert_select "[data-tv-guide-multiplex-axis]", count: 1
    assert_select "[data-tv-guide-multiplex-count='2'].tv-guide-multiplex-level-2", text: "2"
    assert_select "[data-tv-guide-channel='M6.fr']", count: 0
    assert_select "[data-tv-guide-multiplex-count='2'][title*='M6']", count: 1
  end

  test "projects multiplex positions through the same expanded timeline as programmes" do
    programme("TF1", 1, start_minute: 380, duration: 5)
    selected = programme("M6", 6, start_minute: 420, duration: 60)
    Tv::RecordingIntent.create!(broadcast_observation: selected,
                               effective_padding_before_seconds: 0, effective_padding_after_seconds: 0)

    get tv_guide_url, params: { guide_source_id: @source.id, date: "2030-01-01", zoom: 2 }

    assert_select "[data-tv-guide-multiplex-segment][data-tv-guide-top-pixels='854.0']", count: 1
  end

  test "shows an unknown multiplex distinctly" do
    selected = programme("Inconnue", 99)
    Tv::RecordingIntent.create!(broadcast_observation: selected)

    get tv_guide_url, params: { guide_source_id: @source.id, date: "2030-01-01" }

    assert_select "[data-tv-guide-multiplex-unknown='true'].tv-guide-multiplex-unknown", text: "?"
  end

  private

  def programme(name, number, favorite: true, imported: true, start_minute: 1080, duration: 60)
    @sequence += 1
    channel = Tv::Channel.find_or_create_by!(logical_number: number) do |entry|
      entry.display_name = name
      entry.kaffeine_name = name
      entry.favorite = favorite
    end
    guide_channel = @source.guide_channels.find_or_create_by!(external_id: "#{name}.fr", channel:)
    starts_at = Time.find_zone!("Europe/Paris").local(2030, 1, 1) + start_minute.minutes
    observation = guide_channel.broadcast_observations.create!(
      fingerprint: format("%064x", @sequence), starts_at:, ends_at: starts_at + duration.minutes,
      titles: [{ "value" => "Programme #{@sequence}" }]
    )
    @import.guide_import_observations.create!(broadcast_observation: observation) if imported
    observation
  end
end
