require 'test_helper'
require 'minitest/mock'
require 'uri'

class RecordSearchNavigationTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(email: 'search-navigation@example.com', password: 'password')
    @other = User.create!(email: 'search-navigation-other@example.com', password: 'password')
    sign_in @user
    @language = LanguageVersion.create!(short_name: 'SCTX', long_name: 'Version contexte recherche')
    @genre = Gender.create!(name: 'Genre contexte navigation')
    series = make_record('Série', 'series')
    @parent = make_record('Saison 1', 'season', parent: series, rank: 1)
    @record = make_record('Garder cet épisode', 'episode', parent: @parent, rank: 1)
    @query = { 'q' => { 'french_title_or_original_title_cont' => 'Garder', 's' => 'id desc' },
               'filters' => { 'gender_id' => @genre.id.to_s, 'year' => '2020', 'rating' => 'unrated' }, 'page' => '1' }
    @token = RecordSearchContext.issue(user: @user, query: @query)
  end

  test 'deleting from a filtered index returns to the search instead of the parent' do
    get records_path, params: @query
    row = css_select("[data-record-state-row='#{@record.id}']").sole
    link = row.at_css('a[data-turbo-method=delete]')
    assert link
    assert_difference('Record.count', -1) { delete link['href'] }
    assert_response :see_other
    assert_redirected_to records_path(@query)
    follow_redirect!
    assert_select "[data-record-state-row='#{@record.id}']", count: 0
    assert_select '[name="q[french_title_or_original_title_cont]"][value=Garder]', count: 1
    assert_select '#filters_gender_id option[selected]', text: @genre.name
    assert_select '[name="filters[rating]"][value=unrated]', count: 1
  end

  test 'editing and a failed save retain the same context until the search is refreshed' do
    get edit_record_path(@record, search_context: @token)
    assert_select 'input[name=search_context]', count: 1 do |nodes|
      assert_equal @token, nodes.first['value']
    end
    patch record_path(@record), params: {
      search_context: @token, record: { french_title: '', original_title: '' }
    }
    assert_response :unprocessable_content
    assert_select 'input[name=search_context]', count: 1
    patch record_path(@record), params: { search_context: @token, record: { french_title: 'Ne correspond plus' } }
    assert_redirected_to records_path(@query)
    follow_redirect!
    assert_select "[data-record-state-row='#{@record.id}']", count: 0
  end

  test 'creating a record from a search returns to that search' do
    get new_record_path(search_context: @token)
    assert_select 'input[name=search_context]', count: 1
    assert_difference('Record.count', 1) do
      post records_path, params: {
        search_context: @token,
        record: { french_title: 'Nouveau résultat', record_kind: 'standalone_video',
                  language_version_id: @language.id }
      }
    end
    assert_redirected_to records_path(@query)
  end

  test 'an empty final page falls back to the previous page with its criteria intact' do
    make_record('Garder deuxième', 'standalone_video')
    make_record('Garder troisième', 'standalone_video')
    Record.stub(:default_per_page, 2) do
      query = @query.merge('page' => '2')
      token = RecordSearchContext.issue(user: @user, query: query)
      delete record_path(@record), params: { search_context: token }
      assert_redirected_to records_path(query)
      follow_redirect!
      assert_select '[data-record-state-row]', count: 2
      assert_select '[name="q[french_title_or_original_title_cont]"][value=Garder]', count: 1
    end
  end

  test 'two tabs do not overwrite each others search context' do
    get records_path, params: { q: { french_title_cont: 'Autre onglet' } }
    patch record_path(@record), params: { search_context: @token, record: { original_title: 'Original corrigé' } }
    assert_redirected_to records_path(@query)
  end

  test 'an invalid token or another account token cannot choose the return context' do
    ['tampered', RecordSearchContext.issue(user: @other, query: @query)].each do |token|
      patch record_path(@record), params: { search_context: token, record: { original_title: 'Original corrigé' } }
      assert_redirected_to record_path(@record)
    end
  end

  test 'removing the search anchor drops only the missing tree criterion' do
    query = @query.deep_dup
    query['filters']['tree_id'] = @record.id.to_s
    token = RecordSearchContext.issue(user: @user, query: query)
    delete record_path(@record), params: { search_context: token }
    assert_redirected_to records_path(@query)
  end

  test 'rating a filtered result refreshes the current search without resetting it' do
    patch record_rating_path(@record), params: { search_context: @token, rating: { value: 4 } },
                                       headers: { 'Turbo-Frame' => "rating_record_#{@record.id}",
                                                  'Accept' => 'text/vnd.turbo-stream.html' }
    assert_response :success
    assert_equal 'text/vnd.turbo-stream.html', response.media_type
    assert_select 'turbo-stream[action=refresh]', count: 1
    assert_equal 4, RecordRating.find_by!(record: @record, user: @user).value
    get records_path, params: @query
    assert_select "[data-record-state-row='#{@record.id}']", count: 0
  end

  test 'detail and live refresh keep the link back to the same filtered list' do
    get record_path(@record, search_context: @token)
    menu = css_select('turbo-frame#global_record_search').sole['src']
    query = Rack::Utils.parse_nested_query(URI.parse(menu).query)
    assert_equal @query['q'], query['q']
    assert_equal @query['filters'], query['filters']
    source = css_select('[data-record-live-url-value]').sole['data-record-live-url-value']
    assert_equal @token, Rack::Utils.parse_nested_query(URI.parse(source).query)['search_context']
    get source, as: :json
    assert_response :success
    html = Nokogiri::HTML.fragment(response.parsed_body.fetch('html'))
    link = html.css('a').find { |node| node.text.include?("Retour à la liste d'enregistrements") }
    assert_equal records_path(@query), link['href']
  end

  private

  def make_record(title, kind, **attributes)
    Record.create!(french_title: title, record_kind: kind, language_version: @language,
                   year: 2020, genders: [@genre], **attributes)
  end
end
