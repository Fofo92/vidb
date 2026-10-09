# frozen_string_literal: true

require 'test_helper'

class EncodingSeriesPilotTest < ActiveSupport::TestCase
  DIRECTORY = '/videos/Séries TV/_incomplet/9-1-1 (VI - 66_84)'

  test 'title and number agreement prepares a hierarchy without changing the database' do
    assert_no_difference ['Record.count', 'VideoAsset.count', 'CatalogueEpisodeLink.count'] do
      result = pilot(inventory([file])).call
      assert_equal({ 'mapping_proposal' => 1 }, result[:counts])
      assert_equal 1, result[:mapping][:episodes].size
      assert_equal 4005, result[:mapping][:episodes].first[:tmdb_episode_id]
      assert_equal({ 'create_proposal' => 1 }, result[:hierarchy_plan][:summary])
      assert result[:read_only]
    end
  end

  test 'number alone does not identify an episode' do
    result = pilot(inventory([file(stem: 'S04 E05 - Un autre titre')])).call
    assert_equal({ 'title_unmatched' => 1 }, result[:counts])
    assert_empty result[:mapping][:episodes]
    assert_nil result[:hierarchy_plan]
  end

  test 'a recently modified copy and an encoder workspace stay pending' do
    recent = file(modified_at: '2026-10-09T09:00:00Z')
    workspace = file(path: "#{DIRECTORY}/video_encoder_example_workspace/S04 E05 - Suis ta route.mkv")
    result = pilot(inventory([recent, workspace])).call
    assert_equal({ 'awaiting_stability' => 1, 'excluded_workspace' => 1 }, result[:counts])
    assert_empty result[:mapping][:episodes]
  end

  test 'contradictory season directories prevent a mapping proposal' do
    wrong = file(path: "#{DIRECTORY}/Saison 05/S04 E05 - Suis ta route.mkv")
    result = pilot(inventory([wrong])).call
    assert_equal({ 'season_directory_conflict' => 1 }, result[:counts])
    assert_empty result[:mapping][:episodes]
  end

  test 'multiple encodings of the same number are preserved for review' do
    alternative = file(path: "#{DIRECTORY}/Saison 04/S04 E05 - Suis ta route.m4v", extension: '.m4v')
    result = pilot(inventory([file, alternative])).call
    assert_equal({ 'multiple_copies_require_review' => 2 }, result[:counts])
    assert_empty result[:mapping][:episodes]
  end

  test 'a project without a final copy is not a hierarchy or availability proposal' do
    input = inventory([])
    input[:pairs] = [{ directory: "#{DIRECTORY}/Saison 04", status: 'json_only' }]
    result = pilot(input).call
    assert_equal 1, result[:project_only_count]
    assert_empty result[:mapping][:episodes]
    assert_nil result[:hierarchy_plan]
  end

  test 'another series identity and inaccessible paths stop preparation' do
    bad = snapshot.merge(tmdb_series_id: 123)
    assert_raises(ArgumentError) { pilot(inventory([]), snapshot: bad).call }
    input = inventory([{ path: "#{DIRECTORY}/private", type: 'inaccessible' }])
    assert_raises(ArgumentError) { pilot(input).call }
  end

  private

  def pilot(input, snapshot: self.snapshot)
    root = { id: 7335, french_title: '9-1-1', original_title: '9-1-1', record_kind: 'series', ancestry: nil, rank: nil }
    CatalogEnrichment::EncodingSeriesPilot.new(config: config, snapshot: snapshot, inventory: input,
                                              catalogue: [root], now: Time.utc(2026, 10, 9, 10))
  end

  def config
    { format: 'vidb.encoding_series_pilot_config', version: 1, root_record_id: 7335,
      series_title: '9-1-1', original_series_title: '9-1-1', tmdb_series_id: 75219, directory: DIRECTORY }
  end

  def snapshot
    { format: 'vidb.tmdb_series_snapshot', version: 1, retrieved_at: '2026-10-09T10:00:00Z', tmdb_series_id: 75219,
      series: { original_name: '9-1-1' }, episodes: [{ tmdb_episode_id: 4005, season_number: 4, episode_number: 5,
                                                    title_fr: 'Suis ta route', title_original: 'Buck Begins' }] }
  end

  def inventory(entries)
    { format: 'vidb.video_library_inventory', version: 1, generated_at: '2026-10-09T10:00:00Z',
      roots: [DIRECTORY], entries: entries, pairs: [] }
  end

  def file(**overrides)
    stem = 'S04 E05 - Suis ta route (Buck Begins)'
    { path: "#{DIRECTORY}/Saison 04/#{stem}.mkv", relative_path: "Saison 04/#{stem}.mkv", type: 'file',
      extension: '.mkv', size: 100, modified_at: '2026-10-07T00:00:00Z', stem: stem,
      episode: { season: 4, episode: 5 } }.merge(overrides)
  end
end
