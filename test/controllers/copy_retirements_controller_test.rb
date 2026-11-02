require 'test_helper'

class CopyRetirementsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(email: 'retirement-controller@example.com', password: 'password')
    sign_in @user
    language = LanguageVersion.create!(short_name: 'RTC', long_name: 'Version test')
    @record = Record.create!(french_title: 'Terreurs', record_kind: 'standalone_video', language_version: language)
    @old = @record.video_assets.create!(status: 'missing', last_known_path: '/videos/old_vf.mkv')
    @current = @record.video_assets.create!(last_known_path: '/videos/current.mkv')
  end

  test 'missing copies offer a confirmation distinct from physical deletion' do
    get record_url(@record)
    assert_select "[data-video-asset='#{@old.id}'] a[href='#{new_copy_retirement_path(video_asset_ids: [@old.id])}']"
    assert_select "[data-video-asset='#{@current.id}'] a[title='Supprimer cette copie…']", count: 1
  end

  test 'deleted copy details are retained inside a closed history disclosure' do
    @old.update!(status: 'deleted')
    get record_url(@record)
    assert_select '[data-confirmed-video-assets]', count: 1
    assert_select "[data-confirmed-video-assets] [data-video-asset='#{@old.id}']", count: 0
    assert_select '[data-copy-history]:not([open])', count: 1
    assert_select "[data-copy-history] [data-video-asset='#{@old.id}']", count: 1
    assert_select "[data-confirmed-video-assets] [data-video-asset='#{@current.id}']", count: 1
  end

  test 'opening confirmation is a read-only step' do
    service = Object.new
    service.define_singleton_method(:confirmation) { |_ids| { assets: [@asset], token: 'signed' } }
    service.instance_variable_set(:@asset, @old)
    VideoAssets::MissingCopyRetirement.stub(:new, ->(*_args, **_kwargs) { service }) do
      get new_copy_retirement_url, params: { video_asset_ids: [@old.id] }
    end
    assert_response :success
    assert_select 'input[name="confirmation"][value="signed"]'
    assert_select 'input[type="submit"][value="Oui, ces fichiers ont été supprimés"]'
    assert @old.reload.status_missing?
  end

  test 'invalid confirmations do not retire references' do
    post copy_retirements_url, params: { confirmation: 'invalid' }
    assert_redirected_to library_inventory_path
    assert @old.reload.status_missing?
  end

  test 'authentication is required for confirmation and application' do
    sign_out @user
    get new_copy_retirement_url, params: { video_asset_ids: [@old.id] }
    assert_redirected_to new_user_session_path
    post copy_retirements_url, params: { confirmation: 'invalid' }
    assert_redirected_to new_user_session_path
  end

  test 'inventory batch selection is restricted to missing references with absent paths' do
    reader = Struct.new(:call).new({ entries: [], inventory_at: Time.current.iso8601 })
    VideoAssets::InventorySnapshot.stub(:new, -> { reader }) { get library_inventory_url }
    assert_response :success
    assert_select "form#missing-copy-selection[action='#{new_copy_retirement_path}'][method='get']", count: 1
    assert_select "input[type='checkbox'][value='#{@old.id}'][form='missing-copy-selection']", count: 1
    assert_select "input[type='checkbox'][value='#{@current.id}'][form='missing-copy-selection']", count: 0
  end
end
