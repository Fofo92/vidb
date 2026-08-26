require "test_helper"

class CountriesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(
      email: "test@example.com",
      password: "password"
    )

    sign_in @user
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
end
