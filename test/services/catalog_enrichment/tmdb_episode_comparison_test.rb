# frozen_string_literal: true

require 'test_helper'

class TmdbEpisodeComparisonTest < ActiveSupport::TestCase
  test 'title agreement exposes numbering differences and existing unplaced records without changing them' do
    catalogue = [{ 'id' => 1, 'french_title' => 'Les Pendules', 'original_title' => 'The Clocks', 'ancestry' => nil }]
    before = catalogue.deep_dup
    result = compare('S12 E01 - Les Pendules (The Clocks)', catalogue: catalogue)
    assert_equal 'title_number_conflict', result[:status]
    assert_equal 4, result[:tmdb_candidates].first['episode_number']
    assert_equal 1, result[:catalogue_candidates].first['id']
    assert_not result[:accepted]
    assert_equal before, catalogue
  end

  test 'an agreeing number with a different title is not accepted' do
    assert_equal 'title_unmatched', compare('S12 E04 - Autre œuvre')[:status]
  end

  test 'matching title and number are only a proposal' do
    result = compare('S12 E04 - Les Pendules')
    assert_equal 'title_and_number_agree', result[:status]
    assert_not result[:accepted]
  end

  test 'duplicate external titles remain ambiguous' do
    assert_equal 'title_ambiguous', compare('S12 E04 - Les Pendules', duplicate: true)[:status]
  end

  private

  def compare(stem, catalogue: [], duplicate: false)
    episode = { season_number: 12, episode_number: 4, title_fr: 'Les Pendules', title_original: 'The Clocks' }
    episodes = duplicate ? [episode, episode.merge(episode_number: 1)] : [episode]
    snapshot = { format: 'vidb.tmdb_series_snapshot', tmdb_series_id: 790, episodes: episodes }
    report = { 'format' => 'vidb.video_asset_reconciliation', 'source_inventory' => {},
               'observations' => [{ 'path' => "/videos/Poirot/Saison 12/#{stem}.m4v", 'stem' => stem },
                                  { 'path' => '/videos/Poirot-autre/excluded.m4v', 'stem' => stem }] }
    result = CatalogEnrichment::TmdbEpisodeComparison.new(
      snapshot: snapshot, reconciliation: report, directory: '/videos/Poirot', catalogue: catalogue
    ).call
    assert_equal 1, result[:observations].length
    result[:observations].first
  end
end
