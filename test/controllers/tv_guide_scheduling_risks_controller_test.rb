require "test_helper"

class TvGuideSchedulingRisksControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(email: "capacity-preview@example.com", password: "password")
    sign_in @user
    @source = Tv::GuideSource.create!(name: "risk_api", display_name: "Risk API")
    channel = Tv::Channel.create!(display_name: "M6", kaffeine_name: "M6")
    guide_channel = @source.guide_channels.create!(external_id: "M6.fr", channel:)
    @programme = guide_channel.broadcast_observations.create!(
      fingerprint: "b" * 64, starts_at: Time.utc(2030, 1, 1, 18), ends_at: Time.utc(2030, 1, 1, 19),
      titles: [{ "value" => "Film" }]
    )
    imported = @source.guide_imports.create!(document_sha256: "c" * 64, document_byte_size: 100,
                                           status: "succeeded", started_at: Time.utc(2030, 1, 1, 8),
                                           finished_at: Time.utc(2030, 1, 1, 8, 1))
    imported.guide_import_observations.create!(broadcast_observation: @programme)
  end

  test "returns a read only capacity preview from one Kaffeine snapshot" do
    client = Struct.new(:schedules).new([])
    Tv::KaffeineDbus.stub(:new, client) do
      assert_no_difference("Tv::RecordingIntent.count") { request_preview }
    end

    assert_response :success
    result = response.parsed_body
    assert result.fetch("available")
    assert_nil result.fetch("risks").fetch(@programme.id.to_s)
  end

  test "excludes observations outside the requested guide day" do
    client = Struct.new(:schedules).new([])
    Tv::KaffeineDbus.stub(:new, client) { request_preview(date: "2030-01-03") }

    assert_response :success
    assert_empty response.parsed_body.fetch("risks")
  end

  test "rejects an invalid date without contacting Kaffeine" do
    request_preview(date: "invalid")

    assert_response :bad_request
  end

  test "requires authentication" do
    sign_out @user
    request_preview

    assert_includes [401, 302], response.status
  end

  private

  def request_preview(date: "2030-01-01")
    post tv_guide_scheduling_risks_url,
         params: { guide_source_id: @source.id, date:, programme_ids: [@programme.id] }, as: :json
  end
end
