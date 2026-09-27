require "test_helper"
require "minitest/mock"

class TvKaffeineSchedulesIndexTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    sign_in User.create!(email: "kaffeine-overview@example.com", password: "password")
  end

  test "shows Kaffeine schedules independently of vidb selections" do
    schedule = schedule_for(key: 959)
    client = Struct.new(:schedules).new([schedule])

    Tv::KaffeineDbus.stub(:new, client) do
      get tv_kaffeine_schedules_url
    end

    assert_response :success
    assert_select "[data-kaffeine-schedule='959']", text: /Kaffeine uniquement/
    assert_select "[data-kaffeine-schedule='959']", text: /Oublie-moi/
    assert_select "[data-kaffeine-schedule='959'] form", count: 0
  end

  test "labels schedules actually linked to vidb" do
    schedule = schedule_for(key: 982)
    source = Tv::GuideSource.create!(name: "xml_tv_fr", display_name: "XML TV Fr")
    guide_channel = source.guide_channels.create!(external_id: "France4.fr")
    observation = guide_channel.broadcast_observations.create!(
      fingerprint: "c" * 64,
      starts_at: Time.utc(2030, 1, 1, 18),
      ends_at: Time.utc(2030, 1, 1, 19),
      titles: [{ "value" => "Oublie-moi", "language" => "fr" }]
    )
    intent = Tv::RecordingIntent.create!(broadcast_observation: observation)
    Tv::KaffeineScheduleLink.attach!(recording_intent: intent, schedule:, origin: :preexisting)
    client = Struct.new(:schedules).new([schedule])

    Tv::KaffeineDbus.stub(:new, client) do
      get tv_kaffeine_schedules_url
    end

    assert_select "[data-kaffeine-schedule='982']", text: /Liée à vidb \(intention #{intent.id}\)/
  end

  private

  def schedule_for(key:)
    Tv::KaffeineSchedule.new(
      key:, name: "Oublie-moi", channel: "France 4",
      starts_at: Time.utc(2030, 1, 1, 18), duration_seconds: 6300,
      repeat: 0, non_inactive: false
    )
  end
end
