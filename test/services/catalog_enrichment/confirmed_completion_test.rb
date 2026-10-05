# frozen_string_literal: true

require 'test_helper'

class ConfirmedCompletionTest < ActiveSupport::TestCase
  setup do
    language = LanguageVersion.create!(short_name: 'VF', long_name: 'Version française')
    @root = Record.create!(french_title: 'Europe test', language_version: language)
    @country = Country.find_or_create_by!(long_name: 'France') { |country| country.short_name = 'FR' }
    @genre = Gender.find_or_create_by!(name: 'Documentaire')
    CatalogEnrichment::ConfirmedHierarchy.new(
      record_id: @root.id, series_title: @root.french_title, episode_titles: ['Premier', 'Deuxième']
    ).call(apply: true)
    @evidence = {
      'format' => 'vidb.confirmed_episode_hierarchy', 'version' => 1, 'confirmed_by_viewing' => true,
      'local_season_number' => 1, 'record_id' => @root.id, 'series_title' => @root.french_title,
      'episode_titles' => ['Premier', 'Deuxième'],
      'confirmed_paths' => ['/videos/S01 E01 - Premier.m4v', '/videos/S01 E02 - Deuxième.m4v'],
      'accepted_metadata' => { 'countries' => ['France'], 'genre_dictionary_names' => ['Documentaire'],
                               'episode_production_year' => 2022 }
    }
    @observer = lambda do |path|
      { path: path, byte_size: 1234, duration_minutes: 53, measured_duration_seconds: 3202.56,
        container: 'mov,mp4', observed_at: Time.current }
    end
  end

  test 'preview does not change metadata or create assets' do
    assert_no_difference('VideoAsset.count') { service.call }
    assert_empty @root.reload.country_ids
    assert_nil episodes.first.year
  end

  test 'applies leaf year inherited countries and genre and measured copies' do
    assert_difference('VideoAsset.count', 2) { service.call(apply: true) }
    [@root.reload, @root.children.sole, *episodes].each do |record|
      assert_equal [@country.id], record.country_ids
      assert_equal [@genre.id], record.gender_ids
    end
    episodes.each do |episode|
      assert_equal 2022, episode.year
      assert_nil episode.length_in_mn
      assert_equal true, episode.is_recorded
      assert_equal true, episode.is_available
      assert_nil episode.is_seen
      assert_equal false, episode.is_checked
      assert_equal 53, episode.video_assets.sole.duration_minutes
    end
    assert_equal 2, @root.state_counts[:is_available][:yes]
    assert_equal '2022', @root.display_range_of_years
  end

  test 'rerun refreshes copies without duplicates' do
    service.call(apply: true)
    assert_no_difference('VideoAsset.count') { service.call(apply: true) }
  end

  test 'existing conflicting country stops the entire operation' do
    other = Country.create!(short_name: 'IT', long_name: 'Italie')
    episodes.last.countries << other
    assert_no_difference('VideoAsset.count') { assert_raises(ArgumentError) { service.call(apply: true) } }
    assert_empty @root.reload.country_ids
    assert_nil episodes.first.year
  end

  test 'missing dictionaries never create dictionary entries automatically' do
    @evidence['accepted_metadata']['countries'] = ['Inconnu']
    assert_no_difference('Country.count') { assert_raises(ArgumentError) { service.call(apply: true) } }
    assert_empty VideoAsset.where(record_id: episodes.map(&:id))
  end

  test 'a present path on another work stops all metadata changes' do
    other = Record.create!(french_title: 'Autre', language_version: @root.language_version)
    VideoAsset.create!(record: other, last_known_path: @evidence['confirmed_paths'].last)
    assert_no_difference('VideoAsset.count') { assert_raises(ArgumentError) { service.call(apply: true) } }
    assert_empty @root.reload.country_ids
    assert_nil episodes.first.year
  end

  test 'file observation failure does not change the catalog' do
    @observer = ->(_path) { raise ArgumentError, 'File missing' }
    assert_no_difference('VideoAsset.count') { assert_raises(ArgumentError) { service.call(apply: true) } }
    assert_empty @root.reload.gender_ids
  end

  test 'a conflicting episode year is preserved and blocks the batch' do
    episodes.last.update!(year: 2020)
    assert_no_difference('VideoAsset.count') { assert_raises(ArgumentError) { service.call(apply: true) } }
    assert_empty @root.reload.country_ids
    assert_nil episodes.first.year
    assert_equal 2020, episodes.last.year
  end

  test 'a late asset failure rolls back earlier assets states and metadata' do
    failing_path = @evidence['confirmed_paths'].last
    validation = -> { errors.add(:base, 'test failure') if last_known_path == failing_path }
    VideoAsset.validate validation
    assert_no_difference('VideoAsset.count') do
      assert_raises(ActiveRecord::RecordInvalid) { service.call(apply: true) }
    end
    assert_empty @root.reload.country_ids
    assert_nil episodes.first.year
    assert_nil episodes.first.is_recorded
    assert_nil episodes.first.is_available
  ensure
    VideoAsset.skip_callback(:validate, :before, validation) if validation
  end

  private

  def episodes
    @root.children.sole.children.order(:rank).to_a
  end

  def service
    CatalogEnrichment::ConfirmedCompletion.new(evidence: @evidence, observer: @observer)
  end
end
