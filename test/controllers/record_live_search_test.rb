require 'test_helper'
require 'uri'

class RecordLiveSearchTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(email: 'live-search@example.com', password: 'password')
    @other = User.create!(email: 'live-search-other@example.com', password: 'password')
    sign_in @user
    @language = LanguageVersion.create!(short_name: 'LIVQ', long_name: 'Version recherche instantanée')
    @genre = Gender.create!(name: 'Genre recherche instantanée')
    @record = film('Titre français', original_title: 'Hidden original')
    @unrelated = film('Autre œuvre', original_title: '')
  end

  test 'the search input stays outside the frame and automatic requests replace the history entry' do
    get records_url, params: { q: { s: 'id desc' }, filters: { gender_id: @genre.id, rating: 'unrated' } }
    assert_response :success
    assert_select 'form[data-controller="record-live-search"]' do
      assert_select 'input[data-record-live-search-target=input]', count: 1
      assert_select 'input[name="q[s]"][value="id desc"]', count: 1
      assert_select 'input[name="filters[rating]"][value=unrated]', count: 1
      assert_select 'button[hidden][formaction="/records"][data-turbo-frame=record_search_results][data-turbo-action=replace]'
    end
    assert_select 'turbo-frame#record_search_results[target="_top"][data-turbo-action=replace]' do
      assert_select 'form[data-record-filters]', count: 0
      assert_select '.record-genre-bar', count: 1
      assert_select '.record-rating-bar', count: 1
    end
  end

  test 'frame requests search the original title and return fresh navigation context' do
    get records_path, params: {
      q: { french_title_or_original_title_cont: 'Hidden' },
      filters: { gender_id: @genre.id, year: 2020 }
    }, headers: { 'Turbo-Frame' => 'record_search_results' }
    assert_response :success
    assert_select "turbo-frame#record_search_results [data-record-state-row='#{@record.id}']", count: 1
    assert_select "[data-record-state-row='#{@unrelated.id}']", count: 0
    metadata = css_select('[data-live-search-context]').sole
    query = Rack::Utils.parse_nested_query(URI.parse(metadata['data-new-record-url']).query)
    context = RecordSearchContext.query(query['search_context'], user: @user)
    assert_equal 'Hidden', context.dig('q', 'french_title_or_original_title_cont')
    assert_equal @genre.id.to_s, context.dig('filters', 'gender_id')
  end

  test 'the global panel previews matching records without replacing the search field' do
    get record_search_path
    assert_select 'input#global_q_french_title_or_original_title_cont', count: 1
    assert_select 'button[hidden][formaction="/record_search/results"][data-turbo-frame=global_record_search_results]'
    assert_select 'turbo-frame#global_record_search_results input', count: 0

    get results_record_search_path, params: { q: { french_title_or_original_title_cont: 'Hidden' } },
                                    headers: { 'Turbo-Frame' => 'global_record_search_results' }
    assert_response :success
    assert_select 'turbo-frame#global_record_search_results[target="_top"]', count: 1
    assert_select '.record-search-preview li', count: 1
    link = css_select('.record-search-preview a').sole
    assert_equal record_path(@record), URI.parse(link['href']).path
    query = Rack::Utils.parse_nested_query(URI.parse(link['href']).query)
    context = RecordSearchContext.query(query['search_context'], user: @user)
    assert_equal 'Hidden', context.dig('q', 'french_title_or_original_title_cont')
  end

  test 'preview rating criteria remain specific to the signed in account' do
    @record.ratings.create!(user: @other, value: 5)
    query = { q: { french_title_or_original_title_cont: 'Hidden' }, filters: { rating: '5' } }
    get results_record_search_path, params: query
    assert_select '.record-search-preview li', count: 0
    query[:filters][:rating] = 'unrated'
    get results_record_search_path, params: query
    assert_select '.record-search-preview li', count: 1
  end

  test 'the preview stays short and retains access to the complete filtered list' do
    11.times { |number| film("Preview #{number}") }
    get results_record_search_path, params: { q: { french_title_or_original_title_cont: 'Preview' } }
    assert_response :success
    assert_select '.record-search-preview li', count: 10
    link = css_select('a').find { |node| node.text == 'Voir la liste complète' }
    query = Rack::Utils.parse_nested_query(URI.parse(link['href']).query)
    assert_equal 'Preview', query.dig('q', 'french_title_or_original_title_cont')
  end

  test 'invalid criteria produce a recoverable frame error and preview requests require authentication' do
    get results_record_search_path, params: { filters: { rating: '6' } }
    assert_response :unprocessable_content
    assert_select 'turbo-frame#global_record_search_results [role=alert]', count: 1
    sign_out @user
    get results_record_search_path
    assert_redirected_to new_user_session_path
  end

  private

  def film(title, **attributes)
    Record.create!(french_title: title, record_kind: 'standalone_video', year: 2020,
                   language_version: @language, genders: [@genre], **attributes)
  end
end
