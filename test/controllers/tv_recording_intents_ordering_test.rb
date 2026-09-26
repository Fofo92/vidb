require "test_helper"

class TvRecordingIntentsOrderingTest <
    ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    sign_in User.create!(
      email: "recording-intents-ordering@example.com",
      password: "password"
    )

    @source = Tv::GuideSource.create!(
      name: "xml_tv_fr",
      display_name: "XML TV Fr"
    )
    @france_two = create_guide_channel(
      "France2.fr",
      "France 2",
      2
    )
    @arte = create_guide_channel(
      "Arte.fr",
      "Arte",
      7
    )
  end

  test "orders each day by logical channel number then time" do
    later_france_two = create_intent(@france_two, 21, "2")
    arte_intent = create_intent(@arte, 18, "3")
    earlier_france_two = create_intent(@france_two, 19, "4")

    get tv_recording_intents_url

    assert_equal(
      [
        earlier_france_two.id.to_s,
        later_france_two.id.to_s,
        arte_intent.id.to_s
      ],
      rendered_intent_ids
    )
  end

  private

  def create_guide_channel(external_id, display_name, logical_number)
    channel = Tv::Channel.create!(
      display_name: display_name,
      logical_number: logical_number
    )

    @source.guide_channels.create!(
      external_id: external_id,
      channel: channel
    )
  end

  def create_intent(guide_channel, hour, fingerprint_character)
    starts_at = paris.local(2026, 9, 27, hour)
    observation = create_observation(
      guide_channel,
      starts_at,
      fingerprint_character
    )

    Tv::RecordingIntentSelector.new(
      broadcast_observation: observation
    ).call
  end

  def create_observation(guide_channel, starts_at, fingerprint_character)
    guide_channel.broadcast_observations.create!(
      starts_at: starts_at,
      ends_at: starts_at + 1.hour,
      fingerprint: fingerprint_character * 64
    )
  end

  def rendered_intent_ids
    css_select("[data-recording-intent]").map do |element|
      element["data-recording-intent"]
    end
  end

  def paris
    ActiveSupport::TimeZone["Europe/Paris"]
  end
end
