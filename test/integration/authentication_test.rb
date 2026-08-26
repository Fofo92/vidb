require "test_helper"

class AuthenticationTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      email: "login@example.com",
      password: "password"
    )
  end

  test "signs in with valid credentials" do
    post user_session_url, params: {
      user: {
        email: @user.email,
        password: "password"
      }
    }

    assert_redirected_to root_url

    get countries_url
    assert_response :success
  end

  test "signs out an authenticated user" do
    post user_session_url, params: {
      user: {
        email: @user.email,
        password: "password"
      }
    }

    delete destroy_user_session_url

    assert_redirected_to root_url

    get countries_url
    assert_redirected_to new_user_session_url
  end
end
