# frozen_string_literal: true

require 'test_helper'

class TmdbHierarchyPlanTest < ActiveSupport::TestCase
  setup do
    @root = record(1, 'Poirot', "Agatha Christie's Poirot")
    @episode = record(2, 'Les Pendules', 'The Clocks').merge('rank' => 1)
    @external = { 'tmdb_episode_id' => 90, 'season_number' => 12, 'episode_number' => 4,
                  'title_fr' => 'Les Pendules', 'title_original' => 'The Clocks' }
    @snapshot = { 'format' => 'vidb.tmdb_series_snapshot', 'version' => 1,
                  'tmdb_series_id' => 790, 'episodes' => [@external] }
    @entry = { 'local_season' => 12, 'local_episode' => 1, 'tmdb_season' => 12, 'tmdb_episode' => 4,
               'tmdb_episode_id' => 90, 'catalogue_title_fr' => 'Les Pendules',
               'title_original' => 'The Clocks', 'expected_record' => @episode.deep_dup }
    @mapping = { 'format' => 'vidb.local_tmdb_episode_mapping', 'version' => 1,
                 'root_record_id' => 1, 'series_title' => 'Poirot', 'tmdb_series_id' => 790,
                 'episodes' => [@entry] }
  end

  test 'local numbering is preserved while external identity differs' do
    result = plan([@root, @episode])
    row = result[:episodes].first
    assert_equal 'reuse_proposal', row[:action]
    assert_equal 1, row[:local_mapping]['local_episode']
    assert_equal 4, row[:local_mapping]['tmdb_episode']
    assert_equal 'create_proposal', result[:seasons].first[:action]
    assert result[:read_only]
    assert_nil @episode['ancestry']
  end

  test 'existing hierarchy is reused without creating duplicate season' do
    season = record(3, 'Saison 12', '').merge('rank' => 12, 'ancestry' => '1')
    @episode['ancestry'] = '1/3'
    @entry['expected_record'] = @episode.deep_dup
    result = plan([@root, season, @episode])
    assert_equal 'reuse_proposal', result[:seasons].first[:action]
    assert_equal 'reuse_proposal', result[:episodes].first[:action]
  end

  test 'a changed pinned record requires review' do
    @episode['rank'] = 7
    assert_equal 'needs_review', plan([@root, @episode])[:episodes].first[:action]
  end

  test 'a title collision prevents a reuse proposal' do
    duplicate = @episode.merge('id' => 9)
    assert_equal 'needs_review', plan([@root, @episode, duplicate])[:episodes].first[:action]
  end

  test 'a previously unknown matching record prevents a creation proposal' do
    @entry.delete('expected_record')
    assert_equal 'needs_review', plan([@root, @episode])[:episodes].first[:action]
    assert_equal 'create_proposal', plan([@root])[:episodes].first[:action]
  end

  test 'a record attached to another series is not proposed for relocation' do
    @episode['ancestry'] = '500/501'
    @entry['expected_record'] = @episode.deep_dup
    assert_equal 'needs_review', plan([@root, @episode])[:episodes].first[:action]
  end

  test 'external identity changes and duplicate numbers are refused' do
    @external['episode_number'] = 2
    assert_raises(ArgumentError) { plan([@root]) }
    @external['episode_number'] = 4
    @mapping['episodes'] << @entry.deep_dup
    assert_raises(ArgumentError) { plan([@root]) }
  end

  test 'root mismatch is refused' do
    @root['french_title'] = 'Autre série'
    assert_raises(ArgumentError) { plan([@root]) }
  end

  private

  def record(id, french_title, original_title)
    { 'id' => id, 'french_title' => french_title, 'original_title' => original_title,
      'record_kind' => 'undetermined', 'ancestry' => nil, 'rank' => nil }
  end

  def plan(catalogue)
    CatalogEnrichment::TmdbHierarchyPlan.new(mapping: @mapping, snapshot: @snapshot, catalogue: catalogue).call
  end
end
