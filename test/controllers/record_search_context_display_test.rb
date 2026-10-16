# frozen_string_literal: true

require 'test_helper'

class RecordSearchContextDisplayTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    sign_in User.create!(email: 'search-context@example.com', password: 'password')
    language = LanguageVersion.create!(short_name: 'CTX', long_name: 'Version contexte')
    @series = Record.create!(french_title: 'Série contexte', record_kind: 'series', language_version: language)
    @season = @series.children.create!(french_title: 'Saison 01', record_kind: 'season', language_version: language)
    @episode = @season.children.create!(french_title: 'Épisode recherché', record_kind: 'episode', rank: 1,
                                        year: 2022, language_version: language)
  end

  test 'unfiltered results do not display a redundant search role column' do
    get records_url
    assert_response :success
    assert_select '[data-search-context-column]', count: 0
    assert_select '[data-search-role]', count: 0
  end

  test 'matching-only search hides the role column' do
    get records_url, params: { filters: { record_kind: 'episode', display: 'matches' } }
    assert_response :success
    assert_select "[data-record-state-row='#{@episode.id}']"
    assert_select '[data-search-context-column]', count: 0
  end

  test 'tree display explicitly separates results from contextual family records' do
    get records_url, params: { filters: { record_kind: 'episode', display: 'trees' } }
    assert_response :success
    assert_select '[data-search-context-column]', text: 'Recherche'
    assert_select "[data-record-state-row='#{@episode.id}'] [data-search-role='match']", text: 'Résultat'
    assert_select "[data-record-state-row='#{@series.id}'] [data-search-role='context']", text: 'Arborescence'
    assert_select "[data-record-state-row='#{@season.id}'] [data-search-role='context']", text: 'Arborescence'
  end
end
