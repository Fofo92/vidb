require 'test_helper'

class RecordChildMetadataModesTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    sign_in User.create!(email: 'branch-metadata@example.com', password: 'password')
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

    get edit_record_child_qualification_url(series),
        params: { descendant_genre_mode: 'parent', descendant_country_mode: 'current' }

    assert_response :success
    assert_select 'strong', text: '1 fiche(s) changeraient'
    assert_select '[data-metadata-review] tbody tr', count: 1 do |rows|
      assert_equal [own.name, common.name], rows.first.css('td').to_a.values_at(2, 3).map(&:text)
    end
    assert_equal 'current', series.reload.descendant_genre_mode
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

    patch metadata_modes_record_child_qualification_url(collection), params: { descendant_genre_mode: 'parent' }
    assert_redirected_to edit_record_child_qualification_path(collection)
    assert_equal 'parent', collection.reload.descendant_genre_mode
    assert_equal 'current', collection.descendant_country_mode
    assert_equal [common], film.reload.effective_genders
    assert_equal [own.id], film.gender_ids

    patch metadata_modes_record_child_qualification_url(collection), params: { descendant_country_mode: 'parent' }
    assert_equal 'parent', collection.reload.descendant_country_mode
    new_film = collection.children.create!(french_title: 'Nouveau film', record_kind: 'standalone_video',
                                           language_version: language)
    assert_equal [common_country], new_film.effective_countries
    assert_empty new_film.country_ids

    get edit_record_child_qualification_url(collection), params: { descendant_genre_mode: 'current' }
    assert_select '[data-metadata-review] tbody tr' do |rows|
      film_row = rows.find { |row| row.at_css("a[href='#{record_path(film)}']") }
      assert_not_nil film_row, 'Le film doit figurer dans la simulation'
      assert_equal [common.name, own.name], film_row.css('td').to_a.values_at(2, 3).map(&:text)
    end

    patch metadata_modes_record_child_qualification_url(collection), params: { descendant_genre_mode: 'current' }
    assert_equal 'current', collection.reload.descendant_genre_mode
    assert_equal [own], film.reload.effective_genders

    patch metadata_modes_record_child_qualification_url(collection), params: { descendant_genre_mode: 'add' }
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
    common_country = Country.create!(short_name: 'JP', long_name: 'Japon branche test')
    own_country = Country.create!(short_name: 'AU', long_name: 'Australie branche test')
    series.countries = [common_country]
    episode.countries = [own_country]

    get edit_record_url(series)
    assert_select 'select[name="record[descendant_genre_mode]"]'

    patch record_url(series), params: {
      record: { descendant_genre_mode: 'parent', descendant_country_mode: 'parent', gender_ids: [replacement.id] }
    }
    assert_redirected_to record_path(series)
    assert_equal 'parent', series.reload.descendant_genre_mode
    assert_equal [replacement], season.reload.effective_genders
    assert_equal [replacement], episode.reload.effective_genders
    assert_equal [own.id], episode.gender_ids
    assert_equal [common_country], episode.effective_countries
    assert_equal [own_country.id], episode.country_ids

    get edit_record_child_qualification_url(season)
    assert_response :success
    assert_select "[data-qualifiable-child='#{episode.id}']" do
      assert_select '[data-child-effective-genres]', text: replacement.name
      assert_select '[data-child-effective-countries]', text: common_country.long_name
    end

    get record_url(episode)
    assert_response :success
    assert_select '.record-show-facts dd', text: replacement.name
    assert_select '.record-show-facts dd', text: common_country.long_name

    patch record_url(series), params: { record: { gender_ids: [original.id] } }
    assert_redirected_to record_path(series)
    assert_equal [original], episode.reload.effective_genders

    patch record_url(series), params: { record: { gender_ids: [''] } }
    assert_response :unprocessable_content
    assert_equal [original.id], series.reload.gender_ids
    assert_equal [original], episode.reload.effective_genders
  end
end
