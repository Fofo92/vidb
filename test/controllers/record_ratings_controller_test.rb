require 'test_helper'
require 'uri'

class RecordRatingsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(email: 'ratings@example.com', password: 'password')
    sign_in @user
    @language = LanguageVersion.create!(short_name: 'AVIS', long_name: 'Version avis')
    @record = Record.create!(french_title: 'Film avis', record_kind: 'standalone_video',
                             language_version: @language, year: 2020)
    @other_user = User.create!(email: 'ratings-other@example.com', password: 'password')
    @headers = { 'Turbo-Frame' => "rating_record_#{@record.id}" }
  end

  test 'all five notes persist and update only the matching Turbo frame' do
    (1..5).each do |value|
      patch record_rating_url(@record), params: { rating: { value: value } }, headers: @headers
      assert_response :success
      assert_equal value, @record.reload.ratings.find_by!(user: @user).value
      assert_select "turbo-frame#rating_record_#{@record.id}", count: 1
      assert_select 'button.record-rating-star.is-filled', count: value
      assert_select "button[name='rating[value]'][value='#{value}'][aria-pressed=true]", count: 1
      assert_select 'button.record-rating-clear', count: 1
    end
    assert_equal 1, RecordRating.where(record: @record).count
  end

  test 'clearing a rating restores the unrated state without creating a zero note' do
    @record.ratings.create!(user: @user, value: 4)
    assert_difference('RecordRating.count', -1) do
      patch record_rating_url(@record), params: { rating: { value: '' } }, headers: @headers
    end
    assert_response :success
    assert_nil @record.reload.ratings.find_by(user: @user)
    assert_select 'button.record-rating-star.is-filled', count: 0
    assert_select 'button.record-rating-clear', count: 0
    assert_select '[role=status]', text: 'Sans avis'
  end

  test 'invalid requests preserve the previous rating and display an error in the frame' do
    @record.ratings.create!(user: @user, value: 3)
    [0, 6, -1, '2.5', '4x', ['2']].each do |value|
      patch record_rating_url(@record), params: { rating: { value: value } }, headers: @headers
      assert_response :unprocessable_content
      assert_equal 3, @record.reload.ratings.find_by!(user: @user).value
      assert_select '[role=alert]', text: /1 à 5/
    end
  end

  test 'missing parameters do not clear a rating' do
    @record.ratings.create!(user: @user, value: 3)
    patch record_rating_url(@record), params: { rating: { other: '1' } }, headers: @headers
    assert_response :bad_request
    assert_equal 3, @record.reload.ratings.find_by!(user: @user).value
  end

  test 'rating changes require authentication and an existing record' do
    patch record_rating_path(record_id: 0), params: { rating: { value: 3 } }, headers: @headers
    assert_response :not_found
    sign_out @user
    assert_no_difference('RecordRating.count') do
      patch record_rating_url(@record), params: { rating: { value: 3 } }, headers: @headers
    end
    assert_redirected_to new_user_session_path
  end

  test 'another account has its own stars and cannot change or clear the first opinion' do
    @record.ratings.create!(user: @user, value: 4)
    sign_in @other_user
    get records_url, params: { q: { french_title_or_original_title_cont: 'Film avis' } }
    assert_select "turbo-frame#rating_record_#{@record.id} button.is-filled", count: 0
    patch record_rating_url(@record), params: { rating: { value: 2, user_id: @user.id } }, headers: @headers
    assert_response :success
    assert_equal 4, RecordRating.find_by!(record: @record, user: @user).value
    assert_equal 2, RecordRating.find_by!(record: @record, user: @other_user).value
    get record_path(@record)
    assert_select "turbo-frame#rating_record_#{@record.id} button.is-filled", count: 2
    patch record_rating_url(@record), params: { rating: { value: '' } }, headers: @headers
    assert_equal 4, RecordRating.find_by!(record: @record, user: @user).value
    assert_nil RecordRating.find_by(record: @record, user: @other_user)
    get records_url, params: { filters: { rating: 4 } }
    assert_select "[data-record-state-row='#{@record.id}']", count: 0
    get records_url, params: { filters: { rating: 'unrated' } }
    assert_select "[data-record-state-row='#{@record.id}']", count: 1
  end

  test 'ordinary HTML submission redirects to the detail page' do
    patch record_rating_url(@record), params: { rating: { value: 2 } }
    assert_response :see_other
    assert_redirected_to record_path(@record)
    get record_path(@record)
    assert_select "turbo-frame#rating_record_#{@record.id} button.is-filled", count: 2
  end

  test 'index rating filtering combines with search and preserves the genre criterion' do
    other = Record.create!(french_title: 'Film avis autre', record_kind: 'standalone_video',
                           language_version: @language, year: 2020)
    genre = Gender.create!(name: 'Genre avis')
    [@record, other].each { |item| item.genders << genre }
    @record.ratings.create!(user: @user, value: 4)
    other.ratings.create!(user: @user, value: 2)
    get records_url, params: {
      q: { french_title_or_original_title_cont: 'Film avis' },
      filters: { gender_id: genre.id, year: 2020, rating: 4 }
    }
    assert_response :success
    assert_select "[data-record-state-row='#{@record.id}'] turbo-frame", count: 1
    assert_select "[data-record-state-row='#{other.id}']", count: 0
    assert_select 'input[name="filters[rating]"][value="4"]', count: 1
    assert_select '[data-rating-filter="4"][aria-current=true]', count: 1

    href = css_select('[data-rating-filter="2"]').sole['href']
    query = Rack::Utils.parse_nested_query(URI.parse(href).query)
    assert_equal genre.id.to_s, query.dig('filters', 'gender_id')
    assert_equal '2020', query.dig('filters', 'year')
    assert_equal 'Film avis', query.dig('q', 'french_title_or_original_title_cont')
    get href
    assert_select "[data-record-state-row='#{other.id}']", count: 1
    assert_select "[data-record-state-row='#{@record.id}']", count: 0

    href = css_select('[data-rating-filter=all]').sole['href']
    query = Rack::Utils.parse_nested_query(URI.parse(href).query)
    assert_nil query.dig('filters', 'rating')
    assert_equal genre.id.to_s, query.dig('filters', 'gender_id')
  end

  test 'rating links reset pagination and allow filtering unrated records' do
    get records_url, params: { filters: { year: 2020 }, page: 2 }
    href = css_select('[data-rating-filter=unrated]').sole['href']
    query = Rack::Utils.parse_nested_query(URI.parse(href).query)
    assert_nil query['page']
    get href
    assert_select "[data-record-state-row='#{@record.id}']", count: 1
  end
end
