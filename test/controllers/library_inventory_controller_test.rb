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

  test 'forcing can be enabled independently and reversed without rewriting the child' do
    language = LanguageVersion.find_or_create_by!(short_name: 'VF') { |row| row.long_name = 'Français inventaire' }
    collection = Record.create!(french_title: 'Collection inventaire', record_kind: 'collection',
                                language_version: language)
    film = collection.children.create!(french_title: 'Film inventaire', record_kind: 'standalone_video',
                                       language_version: language)
    common = Gender.create!(name: 'Genre de collection')
    own = Gender.create!(name: 'Genre du film')
    collection.genders = [common]
    film.genders = [own]
    common_country = Country.create!(short_name: 'CA', long_name: 'Canada inventaire')
    collection.countries = [common_country]

    patch update_metadata_forcing_library_inventory_url,
          params: { root_id: collection.id, field: 'genders', mode: 'parent' }
    assert_redirected_to metadata_review_library_inventory_path(q: collection.id)
    assert_equal 'parent', collection.reload.descendant_genre_mode
    assert_equal 'current', collection.descendant_country_mode
    assert_equal [common], film.reload.effective_genders
    assert_equal [own.id], film.gender_ids

    patch update_metadata_forcing_library_inventory_url,
          params: { root_id: collection.id, field: 'countries', mode: 'parent' }
    assert_equal 'parent', collection.reload.descendant_country_mode
    new_film = collection.children.create!(french_title: 'Nouveau film', record_kind: 'standalone_video',
                                           language_version: language)
    assert_equal [common_country], new_film.effective_countries
    assert_empty new_film.country_ids

    get metadata_review_library_inventory_url, params: { q: collection.id, genres: 'current' }
    assert_select '[data-metadata-review] tbody tr' do |rows|
      assert_equal [common.name, own.name], rows.first.css('td').to_a.values_at(3, 4).map(&:text)
    end

    patch update_metadata_forcing_library_inventory_url,
          params: { root_id: collection.id, field: 'genders', mode: 'current' }
    assert_equal 'current', collection.reload.descendant_genre_mode
    assert_equal [own], film.reload.effective_genders

    patch update_metadata_forcing_library_inventory_url,
          params: { root_id: collection.id, field: 'genders', mode: 'add' }
    assert_equal 'add', collection.reload.descendant_genre_mode
    assert_equal [common, own], film.reload.effective_genders
    assert_equal [own.id], film.gender_ids
  end

  test 'editing the series updates effective child genres and rejects an invalid forced selection' do
    language = LanguageVersion.find_or_create_by!(short_name: 'VF') { |row| row.long_name = 'Français inventaire' }
    series = Record.create!(french_title: 'Série à éditer', record_kind: 'series', language_version: language)
    season = series.children.create!(french_title: 'Saison à éditer', record_kind: 'season', language_version: language)
    episode = season.children.create!(french_title: 'Épisode à conserver', record_kind: 'episode',
                                      language_version: language)
    original, replacement, own = %w[Original Remplacement Particulier].map { |name| Gender.create!(name: name) }
    series.genders = [original]
    episode.genders = [own]

    get edit_record_url(series)
    assert_select 'select[name="record[descendant_genre_mode]"]'

    patch record_url(series), params: { record: { descendant_genre_mode: 'parent', gender_ids: [replacement.id] } }
    assert_redirected_to record_path(series)
    assert_equal 'parent', series.reload.descendant_genre_mode
    assert_equal [replacement], season.reload.effective_genders
    assert_equal [replacement], episode.reload.effective_genders
    assert_equal [own.id], episode.gender_ids

    patch record_url(series), params: { record: { gender_ids: [original.id] } }
    assert_redirected_to record_path(series)
    assert_equal [original], episode.reload.effective_genders

    patch record_url(series), params: { record: { gender_ids: [''] } }
    assert_response :unprocessable_content
    assert_equal [original.id], series.reload.gender_ids
    assert_equal [original], episode.reload.effective_genders
  end

  test 'authentication is required' do
    sign_out :user
    get library_inventory_url
    assert_redirected_to new_user_session_path
  end
end
