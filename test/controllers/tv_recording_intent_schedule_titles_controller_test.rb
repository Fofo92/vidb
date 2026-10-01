require "test_helper"

class TvRecordingIntentScheduleTitlesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    sign_in User.create!(email: "guide-title@example.com", password: "password")
    source = Tv::GuideSource.create!(name: "xml_tv_fr", display_name: "XML TV Fr")
    channel = source.guide_channels.create!(external_id: "Arte.fr")
    @observation = channel.broadcast_observations.create!(
      fingerprint: "a" * 64, starts_at: Time.utc(2030, 1, 1, 18),
      ends_at: Time.utc(2030, 1, 1, 19),
      titles: [{ "value" => "Un documentaire", "language" => "fr" }]
    )
    @intent = Tv::RecordingIntent.create!(broadcast_observation: @observation)
  end

  test "uses the chosen programme title and returns to the same guide day" do
    chooser = Minitest::Mock.new
    chooser.expect(:call, Struct.new(:key).new(123))

    Tv::GuideScheduleTitleChooser.stub(:new, ->(**_options) { chooser }) do
      post tv_recording_intent_schedule_title_url(@intent), params: request_params
    end

    assert_redirected_to tv_guide_path(date: "2030-01-01", zoom: "2")
    assert_equal "Titre Kaffeine confirmé (n° 123).", flash[:notice]
    chooser.verify
  end

  private

  def request_params
    { broadcast_observation_id: @observation.id, date: "2030-01-01", zoom: "2" }
  end
end
