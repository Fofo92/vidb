require 'test_helper'
require 'uri'

class RecordSearchControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(email: 'global-search@example.com', password: 'password')
    sign_in @user
    language = LanguageVersion.create!(short_name: 'SRCH', long_name: 'Version recherche')
    @genre = Gender.create!(name: 'Genre inédit recherche')
    @record = Record.create!(french_title: 'Titre français global', original_title: 'Original global',
                             record_kind: 'standalone_video', language_version: language, genders: [@genre])
  end

  test 'the search magnifier remains in the navigation outside the collapsed menu' do
    [record_path(@record), credits_path].each do |path|
      get path
      assert_response :success
      assert_select 'nav.navbar .record-search-menu > summary[aria-label]', count: 1
      assert_select '#navbarSupportedContent .record-search-menu', count: 0
      assert_select '.record-search-menu:not([open]) turbo-frame#global_record_search[loading=lazy]', count: 1
      assert_select '.record-search-menu form', count: 0
    end
  end

  test 'the index keeps only the title row and a collapsed drawer with all criteria' do
    get records_url, params: { filters: { gender_id: @genre.id, rating: 'unrated' } }
    assert_response :success
    assert_select '.record-search-quick input[name="q[french_title_or_original_title_cont]"]', count: 1
    assert_select '.record-search-extra:not([open]) #filters_gender_id option[selected]', text: @genre.name
    assert_select 'input[name="filters[rating]"][value=unrated]', count: 1
    assert_select '.record-genre-bar > strong', text: 'Genres'
    assert_select ".record-genre-buttons a[data-genre-filter='#{@genre.id}'][title='#{@genre.name}']" do |nodes|
      assert_equal @genre.name, nodes.first['aria-label']
      assert_select 'i.fa-tag', count: 1
    end
  end

  test 'opening the global panel retains the index search criteria but resets pagination' do
    get records_url, params: {
      q: { french_title_or_original_title_cont: 'global' },
      filters: { gender_id: @genre.id, rating: 'unrated' }, page: 2
    }
    source = css_select('turbo-frame#global_record_search').sole['src']
    query = Rack::Utils.parse_nested_query(URI.parse(source).query)
    assert_equal 'global', query.dig('q', 'french_title_or_original_title_cont')
    assert_equal @genre.id.to_s, query.dig('filters', 'gender_id')
    assert_equal 'unrated', query.dig('filters', 'rating')
    assert_nil query['page']
    get source, headers: { 'Turbo-Frame' => 'global_record_search' }
    assert_response :success
    assert_select 'turbo-frame#global_record_search form[action="/records"][data-turbo-frame="_top"]', count: 1
    assert_select '#global_q_french_title_or_original_title_cont[value=global]', count: 1
    assert_select '#global_filters_gender_id option[selected]', text: @genre.name
    assert_select '#filters_gender_id', count: 0
  end

  test 'both French and original titles remain searchable' do
    ['français global', 'Original global'].each do |title|
      get records_url, params: { q: { french_title_or_original_title_cont: title } }
      assert_response :success
      assert_select "[data-record-state-row='#{@record.id}']", count: 1
    end
  end

  test 'the lazy search endpoint requires a signed in account' do
    sign_out @user
    get record_search_path
    assert_redirected_to new_user_session_path
  end
end
