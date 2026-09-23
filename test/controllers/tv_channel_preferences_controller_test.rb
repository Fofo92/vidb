require "test_helper"

class TvChannelPreferencesControllerTest <
    ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    user = User.create!(
      email: "tv-preferences@example.com",
      password: "password"
    )
    sign_in user

    @favorite = Tv::Channel.create!(
      display_name: "France 2",
      logical_number: 2
    )
    @nonfavorite = Tv::Channel.create!(
      display_name: "BFM TV",
      logical_number: 14,
      favorite: false
    )
    @disabled = Tv::Channel.create!(
      display_name: "Chaîne indisponible",
      logical_number: 99,
      enabled: false
    )
  end

  test "displays enabled channels with their favorite state" do
    get edit_tv_channel_preferences_url

    assert_response :success
    assert_channel_checkbox(@favorite, checked: true)
    assert_channel_checkbox(@nonfavorite, checked: false)
    assert_select(
      channel_checkbox(@disabled),
      count: 0
    )
  end

  test "updates favorites among enabled channels" do
    patch tv_channel_preferences_url, params: {
      tv_channel_preferences: {
        channel_ids: ["", @nonfavorite.id.to_s]
      }
    }

    assert_redirected_to tv_guide_path
    assert_not @favorite.reload.favorite?
    assert @nonfavorite.reload.favorite?
    assert @disabled.reload.favorite?
  end

  private

  def assert_channel_checkbox(channel, checked:)
    selector = channel_checkbox(channel)

    assert_select selector, count: 1
    assert_select(
      "#{selector}[checked]",
      count: checked ? 1 : 0
    )
  end

  def channel_checkbox(channel)
    "input[type='checkbox']" \
      "[name='tv_channel_preferences[channel_ids][]']" \
      "[value='#{channel.id}']"
  end
end
