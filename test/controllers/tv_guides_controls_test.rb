require "test_helper"

class TvGuidesControlsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    sign_in User.create!(
      email: "tv-guide-controls@example.com",
      password: "password"
    )

    @source = Tv::GuideSource.create!(
      name: "xml_tv_fr",
      display_name: "XML TV Fr"
    )
  end

  test "updates the guide automatically when a display option changes" do
    get tv_guide_url, params: guide_params

    assert_response :success
    assert_select auto_submit_form_selector do
      assert_date_control
      assert_zoom_controls
      assert_channel_controls
    end
  end

  private

  def guide_params
    {
      date: "2026-09-27",
      guide_source_id: @source.id
    }
  end

  def auto_submit_form_selector
    "form[action='#{tv_guide_path}']" \
      "[method='get']" \
      "[data-controller~='auto-submit']" \
      "[data-action*='change->auto-submit#submit']"
  end

  def assert_date_control
    assert_select(
      "input[type='date'][name='date'][value='2026-09-27']"
    )
  end

  def assert_zoom_controls
    assert_select(
      "input[type='radio'][name='zoom']",
      count: 3
    )
    assert_select(
      "input[type='radio'][name='zoom'][value='2'][checked]",
      count: 1
    )
  end

  def assert_channel_controls
    assert_select("input[type='checkbox'][name='all_channels']", count: 1)
    assert_select(
      "a[href='#{edit_tv_channel_preferences_path}']",
      text: "Gérer mes chaînes favorites"
    )
    assert_select("input[type='submit'], button[type='submit']", count: 0)
  end
end
