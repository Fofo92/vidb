require "test_helper"

class CountriesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(
      email: "test@example.com",
      password: "password"
    )

    sign_in @user

    @country = Country.create!(
      short_name: "BE",
      long_name: "Belgique",
      flag: "🇧🇪"
    )
  end

  test "creates a country" do
    assert_difference("Country.count", 1) do
      post countries_url, params: {
        country: {
          short_name: "FR",
          long_name: "France",
          flag: "🇫🇷"
        }
      }
    end

    assert_redirected_to countries_url
  end

  test "updates a country with valid attributes" do
    patch country_url(@country), params: {
      country: {
        short_name: "CH",
        long_name: "Suisse",
        flag: "🇨🇭"
      }
    }

    assert_redirected_to countries_url
    assert_equal "CH", @country.reload.short_name
    assert_equal "Suisse", @country.long_name
  end

  test "rejects a country creation with invalid attributes" do
    assert_no_difference("Country.count") do
      post countries_url, params: {
        country: {
          short_name: "",
          long_name: "",
          flag: ""
        }
      }
    end

    assert_response :unprocessable_content
  end

  test "rejects a country update with invalid attributes" do
    patch country_url(@country), params: {
      country: {
        short_name: "",
        long_name: ""
      }
    }

    assert_response :unprocessable_content
    assert_equal "BE", @country.reload.short_name
    assert_equal "Belgique", @country.long_name
  end
end
