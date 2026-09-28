require "test_helper"
require "minitest/mock"

class TvRecordingIntentSchedulesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  class FakeClient
    attr_reader :created

    def initialize(entries = [])
      @entries = entries
      @created = []
    end

    def schedules
      @entries
    end

    def create_schedule(**attributes)
      @created << attributes
      @entries << Tv::KaffeineSchedule.new(key: 983, **attributes, non_inactive: false)
      983
    end
  end

  setup do
    sign_in User.create!(email: "tv-schedule@example.com", password: "password")
    source = Tv::GuideSource.create!(name: "xml_tv_fr", display_name: "XML TV Fr")
    channel = Tv::Channel.create!(display_name: "France 2", kaffeine_name: "France 2")
    guide_channel = source.guide_channels.create!(external_id: "France2.fr", channel:)
    observation = guide_channel.broadcast_observations.create!(
      fingerprint: "a" * 64,
      starts_at: Time.utc(2030, 9, 30, 18),
      ends_at: Time.utc(2030, 9, 30, 19, 30),
      titles: [{ "value" => "Le film", "language" => "fr" }]
    )
    @intent = Tv::RecordingIntentSelector.new(broadcast_observation: observation).call
  end

  test "programmes a selected intent once" do
    client = FakeClient.new

    Tv::KaffeineDbus.stub(:new, client) do
      2.times { post tv_recording_intent_schedule_url(@intent) }
    end

    assert_equal 1, client.created.length
    assert_equal 983, @intent.reload.kaffeine_schedule_link.kaffeine_key
    assert_redirected_to tv_recording_intents_url
    assert_match(/confirmée/, flash[:notice])
  end

  test "reports a changed linked schedule without creating another" do
    attributes = Tv::RecordingIntentScheduleAttributes.new(recording_intent: @intent).call
    schedule = Tv::KaffeineSchedule.new(key: 982, **attributes, non_inactive: false)
    Tv::KaffeineScheduleLink.attach!(recording_intent: @intent, schedule:, origin: :created_by_vidb)
    client = FakeClient.new([schedule.with(channel: "TF1")])

    Tv::KaffeineDbus.stub(:new, client) { post tv_recording_intent_schedule_url(@intent) }

    assert_empty client.created
    assert_equal 982, @intent.reload.kaffeine_schedule_link.kaffeine_key
    assert_match(/non confirmée/, flash[:alert])
  end

  test "returns to the guide and shows the confirmed schedule" do
    client = FakeClient.new
    guide_params = {
      return_to: "guide",
      date: "2030-09-30",
      guide_source_id: @intent.broadcast_observation.guide_channel.guide_source_id.to_s,
      zoom: "1",
      all_channels: "1"
    }

    Tv::KaffeineDbus.stub(:new, client) do
      post tv_recording_intent_schedule_url(@intent), params: guide_params
    end

    assert_redirected_to tv_guide_url(guide_params.except(:return_to))
    assert_equal 983, @intent.reload.kaffeine_schedule_link.kaffeine_key
  end
end
