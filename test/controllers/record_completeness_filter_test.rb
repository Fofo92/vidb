require 'test_helper'

class RecordCompletenessFilterTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    sign_in User.create!(email: 'completeness-filter@example.com', password: 'password')
    language = LanguageVersion.create!(short_name: 'CPL', long_name: 'Complétude test')
    @collection = Record.create!(french_title: 'Collection filtre disque', record_kind: 'collection', language_version: language)
    @film = @collection.children.create!(french_title: 'Film filtre disque', record_kind: 'standalone_video', language_version: language)
    @film.video_assets.create!(last_known_path: '/videos/completeness-filter.mkv')
  end

  test 'completeness is accepted and retained by the compact search form' do
    get records_url, params: { filters: { record_kind: 'collection', completeness: 'complete' } }
    assert_response :success
    assert_select "[data-record-state-row='#{@collection.id}']", count: 1
    assert_select "select#filters_completeness option[value='complete'][selected]", count: 1
    assert_select '[data-record-filters] .form-control-sm'
    assert_select '[data-record-filters] .form-select-sm'
    assert_select '[data-record-filter-advanced]:not([open])', count: 1
  end

  test 'missing disk copies make the ensemble incomplete despite old flags' do
    @film.video_assets.first.update!(status: 'missing')
    @film.update_columns(is_available: true)
    get records_url, params: { filters: { tree_id: @collection.id, completeness: 'incomplete' } }
    assert_response :success
    assert_select "[data-record-state-row='#{@collection.id}']", count: 1
  end

  test 'active catalogue controls stay visible and retain their value' do
    get records_url, params: { filters: { tree_id: @collection.id, missing: 'country', review: '1' } }
    assert_response :success
    assert_select '[data-record-filter-advanced][open]', count: 1
    assert_select "select#filters_missing option[value='country'][selected]", count: 1
    assert_select 'input#filters_review[checked]', count: 1
  end
end
