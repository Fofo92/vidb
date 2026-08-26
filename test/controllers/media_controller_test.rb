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

  test "creates a medium" do
    assert_difference("Medium.count", 1) do
      post media_url, params: {
        medium: {
          short_name: "VHS",
          long_name: "Video Home System"
        }
      }
    end

    assert_redirected_to media_url
    assert_equal(
      "Video Home System",
      Medium.find_by!(short_name: "VHS").long_name
    )
  end

  test "rejects a medium creation with invalid attributes" do
    assert_no_difference("Medium.count") do
      post media_url, params: {
        medium: {
          short_name: "",
          long_name: ""
        }
      }
    end

    assert_response :unprocessable_content
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
