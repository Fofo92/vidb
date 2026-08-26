require "test_helper"

class LanguageVersionsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    user = User.create!(
      email: "test@example.com",
      password: "password"
    )
    sign_in user

    @language_version = LanguageVersion.create!(
      short_name: "VF",
      long_name: "Version française"
    )
  end

  test "updates a language version with valid attributes" do
    patch language_version_url(@language_version), params: {
      language_version: {
        short_name: "VOSTFR",
        long_name: "Version originale sous-titrée en français"
      }
    }

    assert_redirected_to language_versions_url
    assert_equal "VOSTFR", @language_version.reload.short_name
    assert_equal(
      "Version originale sous-titrée en français",
      @language_version.long_name
    )
  end

  test "rejects a language version update with invalid attributes" do
    patch language_version_url(@language_version), params: {
      language_version: {
        short_name: "",
        long_name: ""
      }
    }

    assert_response :unprocessable_content
    assert_equal "VF", @language_version.reload.short_name
    assert_equal "Version française", @language_version.long_name
  end
end
