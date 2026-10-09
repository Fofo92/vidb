# frozen_string_literal: true

require 'test_helper'

class LinkedEpisodeCompletionTest < ActiveSupport::TestCase
  setup do
    language = LanguageVersion.create!(short_name: 'IN', long_name: 'Indéterminée')
    Medium.find_or_create_by!(short_name: 'HD') { |medium| medium.long_name = 'Disque dur' }
    @country = Country.find_or_create_by!(long_name: 'Royaume-Uni') { |country| country.short_name = 'GB' }
    @genre = Gender.find_or_create_by!(name: 'Policier')
    @root = Record.create!(french_title: 'Poirot test', record_kind: 'series', language_version: language)
    season = @root.children.create!(french_title: 'Saison 01', record_kind: 'season', rank: 1, language_version: language)
    @episode = season.children.create!(french_title: 'Test', record_kind: 'episode', rank: 1,
                                      language_version: language, is_seen: true, year: 1989, length_in_mn: 50)
    CatalogueEpisodeLink.create!(record: @episode, provider: 'tmdb', external_series_id: 790,
                                 external_episode_id: 9999, local_season_number: 1, local_episode_number: 1,
                                 external_season_number: 1, external_episode_number: 1)
    @evidence = { format: 'vidb.linked_episode_completion', version: 1, root_record_id: @root.id,
                  tmdb_series_id: 790, total: 1, directory: '/videos/Poirot', medium: 'HD', storage_uuid: 'volume',
                  country_dictionary_names: ['Royaume-Uni'], origin_country_codes: ['GB'],
                  genre_dictionary_names: ['Policier'], genre_basis: 'Crime selected',
                  copies: [{ path: '/videos/Poirot/Saison 01/S01 E01 - Test.m4v', size: 100,
                             modified_at: 3.days.ago.iso8601, tmdb_episode_id: 9999, local_season: 1, local_episode: 1 }] }
    @snapshot = { format: 'vidb.tmdb_series_snapshot', tmdb_series_id: 790,
                  series: { origin_country: ['GB'], production_countries: [{ iso_3166_1: 'US' }], genres: [{ id: 80 }] } }
    @observer = Object.new
    @observer.define_singleton_method(:call) do |entry|
      { path: entry[:path], byte_size: 100, duration_minutes: 52, measured_duration_seconds: 3131.0,
        container: 'mov,mp4,m4a,3gp,3g2,mj2', observed_at: Time.current,
        technical_details: { 'streams' => [], 'storage' => { 'uuid' => 'volume' } } }
    end
    @observer.define_singleton_method(:verify!) { |_observed| true }
  end

  test 'preview changes neither copies states nor country and genre associations' do
    assert_no_difference('VideoAsset.count') { assert_not service.call[:applied] }
    assert_empty @root.country_ids
    assert_empty @episode.gender_ids
    assert_equal 50, @episode.reload.length_in_mn
  end

  test 'apply adds measured copies and inherited metadata without theoretical duration or language overwrite' do
    assert_difference('VideoAsset.count', 1) { assert service.call(apply: true)[:applied] }
    asset = @episode.video_assets.sole
    assert_equal 52, asset.duration_minutes
    assert_equal 'HD', asset.medium.short_name
    assert_nil asset.language_version_id
    assert_equal 50, @episode.reload.length_in_mn
    assert_equal 1989, @episode.year
    assert @episode.is_seen
    assert @episode.is_available
    assert @episode.is_recorded
    [@root, *@root.descendants].each do |record|
      assert_equal [@country.id], record.country_ids
      assert_equal [@genre.id], record.gender_ids
    end
  end

  test 'rerun updates the same copy without creating duplicates' do
    service.call(apply: true)
    assert_no_difference('VideoAsset.count') { service.call(apply: true) }
  end

  test 'metadata conflicts block the entire batch' do
    other = Country.create!(long_name: 'France test', short_name: 'FT')
    @root.countries << other
    assert_no_difference('VideoAsset.count') { assert_raises(ArgumentError) { service.call(apply: true) } }
    assert_equal [other.id], @root.country_ids
    assert_empty @episode.gender_ids
  end

  test 'file change at final verification blocks metadata and copy updates' do
    @observer.define_singleton_method(:verify!) { |_observed| raise ArgumentError, 'Changed file' }
    assert_no_difference('VideoAsset.count') { assert_raises(ArgumentError) { service.call(apply: true) } }
    assert_empty @root.country_ids
  end

  test 'late asset validation failure rolls back country and genre assignments' do
    validation = -> { errors.add(:base, 'Late failure') if last_known_path.include?('/videos/Poirot/') }
    VideoAsset.validate validation
    assert_no_difference('VideoAsset.count') do
      assert_raises(ActiveRecord::RecordInvalid) { service.call(apply: true) }
    end
    assert_empty @root.country_ids
    assert_empty @episode.gender_ids
  ensure
    VideoAsset.skip_callback(:validate, :before, validation) if validation
  end
  private

  def service
    CatalogEnrichment::LinkedEpisodeCompletion.new(evidence: @evidence, snapshot: @snapshot, observer: @observer)
  end
end
