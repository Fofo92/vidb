require 'test_helper'
require 'minitest/mock'

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

  test 'metadata simulation can force genres without forcing countries or writing associations' do
    language = LanguageVersion.find_or_create_by!(short_name: 'VF') { |row| row.long_name = 'Français inventaire' }
    series = Record.create!(french_title: 'Série inventaire', record_kind: 'series', language_version: language)
    episode = series.children.create!(french_title: 'Épisode inventaire', record_kind: 'episode',
                                      language_version: language)
    common = Gender.create!(name: 'Drame inventaire')
    own = Gender.create!(name: 'Thriller inventaire')
    series.genders = [common]
    episode.genders = [own]
    series.countries = [Country.create!(short_name: 'BE', long_name: 'Belgique inventaire')]
    country = Country.create!(short_name: 'CH', long_name: 'Suisse inventaire')
    episode.countries = [country]

    get metadata_review_library_inventory_url, params: { q: series.id, genres: 'parent', pays: 'current' }

    assert_response :success
    assert_select 'strong', text: '1 fiche(s) changeraient'
    assert_select '[data-metadata-review] tr' do |rows|
      assert_equal [own.name, common.name], rows[1].css('td').to_a.values_at(2, 4).map(&:text)
      assert_equal rows[2].css('td')[3].text, rows[2].css('td')[4].text
    end
    assert_equal [own.id], episode.reload.gender_ids
    assert_equal [country.id], episode.country_ids
  end

  test 'authentication is required' do
    sign_out :user
    get library_inventory_url
    assert_redirected_to new_user_session_path
  end
end
