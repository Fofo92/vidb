# frozen_string_literal: true

require 'test_helper'

class EncodingPilotComparisonFixTest < ActiveSupport::TestCase
  test 'language suffix is removed for comparison and retained as filename evidence' do
    result = compare('S04 E05 - Suis ta route (Buck Begins)_vf')
    assert_equal 'title_and_number_agree', result[:status]
    assert_equal 'VF', result[:filename_evidence][:language_marker]
    assert_equal 'Suis ta route (Buck Begins)_vf', result[:filename_evidence][:raw_title]
    assert_not result[:accepted]
  end

  test 'a long dash is accepted without renaming the file' do
    result = compare('S04 E05 — Suis ta route (Buck Begins)')
    assert_equal 'title_and_number_agree', result[:status]
    assert_includes result[:path], '—'
  end

  test 'numeric suffix stays under review because it may denote a broadcast part' do
    result = compare('S04 E05 - Suis ta route (Buck Begins) (1)_vf')
    assert_equal 'filename_suffix_requires_review', result[:status]
    assert result[:filename_evidence][:ambiguous_part_suffix]
    assert_not result[:accepted]
  end

  test 'original titles with nested parentheses remain intact' do
    result = CatalogEnrichment::EpisodeFilenameTitle.parse('S01 E07 - Pleine lune (Full Moon (Creepy AF))_vf')
    assert_equal 'Pleine lune (Full Moon (Creepy AF))', result[:title]
    assert_not result[:ambiguous_part_suffix]
  end

  test 'an episode of another series does not block creation in the selected series' do
    other = record(id: 6555, ancestry: '6003/6544')
    plan = plan([other])
    assert_equal 'create_proposal', plan[:episodes].first[:action]
    assert_empty plan[:episodes].first[:candidates]
    assert_equal '6003/6544', other[:ancestry]
  end

  test 'an unplaced homonym still blocks creation and is never moved automatically' do
    plan = plan([record(id: 761, ancestry: nil)])
    assert_equal 'needs_review', plan[:episodes].first[:action]
    assert_equal 761, plan[:episodes].first[:candidates].first['id']
  end

  private

  def compare(stem)
    report = { 'format' => 'vidb.video_asset_reconciliation', 'source_inventory' => {},
               'observations' => [{ 'path' => "/videos/9-1-1/Saison 04/#{stem}.mkv", 'stem' => stem }] }
    snapshot = { format: 'vidb.tmdb_series_snapshot', tmdb_series_id: 75219,
                 episodes: [{ season_number: 4, episode_number: 5, title_fr: 'Suis ta route',
                              title_original: 'Buck Begins' }] }
    CatalogEnrichment::TmdbEpisodeComparison.new(snapshot: snapshot, reconciliation: report,
                                                directory: '/videos/9-1-1').call[:observations].first
  end

  def record(id:, ancestry:)
    { id: id, french_title: 'Le secret', original_title: '', record_kind: 'undetermined', ancestry: ancestry, rank: 1 }
  end

  def plan(candidates)
    mapping = { format: 'vidb.local_tmdb_episode_mapping', version: 1, root_record_id: 7335,
                series_title: '9-1-1', tmdb_series_id: 75219,
                episodes: [{ local_season: 4, local_episode: 4, tmdb_episode_id: 2671295,
                             tmdb_season: 4, tmdb_episode: 4,
                             catalogue_title_fr: 'Le secret', title_original: "9-1-1, What's Your Grievance?" }] }
    snapshot = { format: 'vidb.tmdb_series_snapshot', version: 1, tmdb_series_id: 75219,
                 episodes: [{ tmdb_episode_id: 2671295, season_number: 4, episode_number: 4,
                              title_fr: 'Le secret', title_original: "9-1-1, What's Your Grievance?" }] }
    root = { id: 7335, french_title: '9-1-1', record_kind: 'series', ancestry: nil }
    CatalogEnrichment::TmdbHierarchyPlan.new(mapping: mapping, snapshot: snapshot,
                                           catalogue: [root, *candidates]).call
  end
end
