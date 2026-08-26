require "test_helper"

class RegistrationAccessTest < ActionDispatch::IntegrationTest
  test "public registration routes are unavailable" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "/users/sign_up",
        method: :get
      )
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "/users",
        method: :post
      )
    end
  end

  test "authentication and password recovery routes remain available" do
    sign_in_route = Rails.application.routes.recognize_path(
      "/users/sign_in",
      method: :get
    )
    password_route = Rails.application.routes.recognize_path(
      "/users/password/new",
      method: :get
    )

    assert_equal "devise/sessions", sign_in_route.fetch(:controller)
    assert_equal "new", sign_in_route.fetch(:action)

    assert_equal "devise/passwords", password_route.fetch(:controller)
    assert_equal "new", password_route.fetch(:action)
  end
end
