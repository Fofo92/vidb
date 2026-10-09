# frozen_string_literal: true

require 'test_helper'

class TmdbOriginMetadataTest < ActiveSupport::TestCase
  setup do
    @country = Country.find_or_create_by!(long_name: 'États-Unis') { |country| country.short_name = 'US' }
    @genre = Gender.find_or_create_by!(name: 'Drame')
    language = LanguageVersion.create!(short_name: 'OT', long_name: 'Origin metadata test')
    @root = Record.create!(french_title: 'Origin test', record_kind: 'series', language_version: language)
    @evidence = { 'tmdb_series_id' => 75219, 'origin_country_codes' => ['US'],
                  'country_dictionary_names' => ['États-Unis'], 'expected_tmdb_genre_id' => 18,
                  'genre_dictionary_names' => ['Drame'], 'genre_basis' => 'Major genre selected' }
    @snapshot = { 'format' => 'vidb.tmdb_series_snapshot', 'tmdb_series_id' => 75219,
                  'series' => { 'origin_country' => ['US'], 'genres' => [{ 'id' => 18 }, { 'id' => 80 }] } }
  end

  test 'preview accepts the selected country and genre without updating associations' do
    plan = service.plan.sole
    assert_equal [@country.id], plan[:country_ids]
    assert_equal [@genre.id], plan[:gender_ids]
    assert_empty @root.reload.country_ids
    assert_empty @root.gender_ids
  end

  test 'application propagates only the selected genre' do
    service.apply!
    assert_equal [@country.id], @root.reload.country_ids
    assert_equal [@genre.id], @root.gender_ids
  end

  test 'a missing selected genre blocks completion even when Crime is present' do
    @snapshot['series']['genres'] = [{ 'id' => 80 }]
    assert_raises(ArgumentError) { service }
    assert_empty @root.reload.country_ids
  end

  test 'a changed country of origin blocks completion' do
    @snapshot['series']['origin_country'] = ['GB']
    assert_raises(ArgumentError) { service }
  end

  private

  def service
    CatalogEnrichment::TmdbOriginMetadata.new(evidence: @evidence, snapshot: @snapshot, records: [@root])
  end
end
