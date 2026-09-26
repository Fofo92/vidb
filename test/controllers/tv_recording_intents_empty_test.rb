require "test_helper"

class TvRecordingIntentsEmptyTest <
    ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    sign_in User.create!(
      email: "recording-intents-empty@example.com",
      password: "password"
    )
  end

  test "displays the empty recording summary" do
    get tv_recording_intents_url

    assert_response :success
    assert_select "h1", text: "Enregistrements programmés"
    assert_select(
      "[data-recording-intents-empty]",
      text: "Aucun enregistrement n’est programmé."
    )
    assert_select(
      "a[href='#{tv_recording_intents_path}']",
      text: "Enregistrements"
    )
  end
end
