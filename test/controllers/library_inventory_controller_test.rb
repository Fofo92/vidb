require 'test_helper'

class LibraryInventoryControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    sign_in User.create!(email: 'inventory-tools@example.com', password: 'password')
  end

  test 'the tools menu replaces the CSV placeholder and inventory is read only' do
    snapshot = Struct.new(:call).new(nil)
    VideoAssets::InventorySnapshot.stub(:new, -> { snapshot }) do
      assert_no_difference ['VideoAsset.count', 'Record.count'] do
        get library_inventory_url
      end
    end
    assert_response :success
    assert_select 'h1', text: 'Inventaire et doublons'
    assert_select 'a', text: 'Importation csv', count: 0
    assert_select "a[href='#{library_inventory_path}']", text: 'Inventaire et doublons'
    assert_select '.alert-warning', text: /Aucun inventaire complet/
  end

  test 'inventory refresh uses the existing request mechanism' do
    VideoAssets::ReconciliationRefreshRequest.stub(:path, '/configured/refresh.request') do
      VideoAssets::ReconciliationRefreshRequest.stub(:call, true) do
        post refresh_library_inventory_url
      end
    end
    assert_redirected_to library_inventory_path
  end

  test 'authentication is required' do
    sign_out :user
    get library_inventory_url
    assert_redirected_to new_user_session_path
  end
end
