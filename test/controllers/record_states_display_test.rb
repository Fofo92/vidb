# frozen_string_literal: true

require 'test_helper'

class RecordStatesDisplayTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    sign_in User.create!(email: 'states@example.com', password: 'password')
    language = LanguageVersion.create!(short_name: 'VF', long_name: 'Version française')
    @root = Record.create!(french_title: 'Série', language_version: language, record_kind: 'series')
    season = @root.children.create!(french_title: 'Saison 01', language_version: language, record_kind: 'season')
    @episode = season.children.create!(
      french_title: 'Premier', language_version: language, record_kind: 'episode', is_seen: nil
    )
  end

  test 'series and season counters use episodes and show unknown states' do
    get record_url(@root)
    assert_response :success
    assert_select "[data-record-state-summary='#{@root.id}'] [data-state='is_seen']", text: /0\/1.*1 inconnu/m
  end

  test 'container edit offers counters rather than scalar state controls' do
    get edit_record_url(@root)
    assert_response :success
    assert_select "input[name='record[is_seen]']", count: 0
    assert_select "input[name='record[is_available]']", count: 0
    assert_select "[data-record-state-summary='#{@root.id}']", count: 1
  end

  test 'index displays aggregate states for a series' do
    get records_url
    assert_response :success
    assert_select "[data-record-state-summary='#{@root.id}'] [data-state='is_seen']", text: /0\/1.*1 inconnu/m
  end
end
