require "test_helper"

class RecordsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    user = User.create!(
      email: "test@example.com",
      password: "password"
    )
    sign_in user

    language_version = LanguageVersion.create!(
      short_name: "VF",
      long_name: "Version française"
    )

    @record = Record.create!(
      french_title: "Ancien titre",
      length_in_mn: 90,
      language_version: language_version
    )
  end

  test "updates a record with valid attributes" do
    patch record_url(@record), params: {
      record: {
        french_title: "Nouveau titre",
        length_in_mn: 95
      }
    }

    assert_redirected_to record_url(@record)
    assert_equal "Nouveau titre", @record.reload.french_title
    assert_equal 95, @record.length_in_mn
  end

  test "rejects a record update with invalid attributes" do
    patch record_url(@record), params: {
      record: {
        french_title: "",
        original_title: ""
      }
    }

    assert_response :unprocessable_content
    assert_equal "Ancien titre", @record.reload.french_title
  end

  test "destroys a root record" do
    assert_difference("Record.count", -1) do
      delete record_url(@record)
    end

    assert_redirected_to records_url
  end

  test "redirects to the parent after destroying a child record" do
    child = @record.children.create!(
      french_title: "Épisode",
      length_in_mn: 45,
      language_version: @record.language_version
    )

    assert_difference("Record.count", -1) do
      delete record_url(child)
    end

    assert_redirected_to record_url(@record)
  end
end
