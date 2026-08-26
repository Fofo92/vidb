require "test_helper"

class MediaControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    user = User.create!(
      email: "test@example.com",
      password: "password"
    )
    sign_in user

    @medium = Medium.create!(
      short_name: "DVD",
      long_name: "Digital Versatile Disc"
    )
  end

  test "updates a medium with valid attributes" do
    patch medium_url(@medium), params: {
      medium: {
        short_name: "BR",
        long_name: "Blu-ray"
      }
    }

    assert_redirected_to media_url
    assert_equal "BR", @medium.reload.short_name
    assert_equal "Blu-ray", @medium.long_name
  end

  test "rejects a medium update with invalid attributes" do
    patch medium_url(@medium), params: {
      medium: {
        short_name: "",
        long_name: ""
      }
    }

    assert_response :unprocessable_content
    assert_equal "DVD", @medium.reload.short_name
    assert_equal "Digital Versatile Disc", @medium.long_name
  end
end
