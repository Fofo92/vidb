require "test_helper"

class GendersControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    user = User.create!(
      email: "test@example.com",
      password: "password"
    )
    sign_in user

    @gender = Gender.create!(
      name: "Drame",
      comment: "Genre dramatique"
    )
  end

  test "updates a gender with valid attributes" do
    patch gender_url(@gender), params: {
      gender: {
        name: "Comédie dramatique",
        comment: "Entre comédie et drame"
      }
    }

    assert_redirected_to genders_url
    assert_equal "Comédie dramatique", @gender.reload.name
    assert_equal "Entre comédie et drame", @gender.comment
  end

  test "rejects a gender update with invalid attributes" do
    patch gender_url(@gender), params: {
      gender: {
        name: ""
      }
    }

    assert_response :unprocessable_content
    assert_equal "Drame", @gender.reload.name
  end
end
