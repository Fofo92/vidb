# frozen_string_literal: true

require 'test_helper'

class TmdbArcTitlesTest < ActiveSupport::TestCase
  test 'external arc suffix is comparable without changing its canonical title' do
    result = compare('S08 E01 - Piqûre mortelle (Buzzkill)_vf')
    assert_equal 'title_and_number_agree', result[:status]
    assert_equal 'Buzzkill (1)', result[:tmdb_candidates].sole['title_original']
    assert_not result[:accepted]
  end

  test 'arc title base does not override a different episode number' do
    assert_equal 'title_unmatched', compare('S08 E02 - Piqûre mortelle (Buzzkill)_vf')[:status]
  end

  test 'a numeric suffix on the local file still needs review' do
    assert_equal 'filename_suffix_requires_review', compare('S08 E01 - Piqûre mortelle (Buzzkill) (1)_vf')[:status]
  end

  private

  def compare(stem)
    report = { 'format' => 'vidb.video_asset_reconciliation', 'source_inventory' => {},
               'observations' => [{ 'path' => "/videos/9-1-1/Saison 08/#{stem}.mkv", 'stem' => stem }] }
    snapshot = { format: 'vidb.tmdb_series_snapshot', tmdb_series_id: 75219,
                 episodes: [{ season_number: 8, episode_number: 1, title_fr: 'Piqûre mortelle (1)',
                              title_original: 'Buzzkill (1)' }] }
    CatalogEnrichment::TmdbEpisodeComparison.new(snapshot: snapshot, reconciliation: report,
                                                directory: '/videos/9-1-1').call[:observations].first
  end
end
