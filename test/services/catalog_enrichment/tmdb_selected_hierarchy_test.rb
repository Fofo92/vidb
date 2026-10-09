# frozen_string_literal: true

require 'test_helper'

class TmdbSelectedHierarchyTest < ActiveSupport::TestCase
  test 'an orphan homonym stays excluded while an unblocked episode can be prepared' do
    orphan = { id: 99, french_title: 'Titre 2', original_title: nil, record_kind: 'undetermined', ancestry: nil }
    assert_no_difference ['Record.count', 'VideoAsset.count', 'CatalogueEpisodeLink.count'] do
      result = prepare([root, orphan])
      assert_equal 1, result[:selected_count]
      assert_equal 1, result[:excluded_count]
      assert_equal [101], result[:mapping]['episodes'].pluck('tmdb_episode_id')
      assert_equal 102, result[:excluded].sole.dig(:local_mapping, 'tmdb_episode_id')
      assert_equal({ 'create_proposal' => 1 }, result[:hierarchy_plan][:summary])
    end
  end

  test 'a contradictory season prevents selecting all its episodes' do
    season = { id: 98, french_title: 'Saison 01', record_kind: 'standalone_video', ancestry: '7335', rank: 1 }
    assert_raises(ArgumentError) { prepare([root, season]) }
  end

  private

  def prepare(catalogue)
    CatalogEnrichment::TmdbSelectedHierarchy.new(mapping: mapping, snapshot: snapshot, catalogue: catalogue).call
  end

  def root
    { id: 7335, french_title: '9-1-1', original_title: '9-1-1', record_kind: 'series', ancestry: nil }
  end

  def mapping
    { format: 'vidb.local_tmdb_episode_mapping', version: 1, root_record_id: 7335,
      series_title: '9-1-1', tmdb_series_id: 75219, episodes: [1, 2].map { |number| episode(number) } }
  end

  def episode(number)
    { local_season: 1, local_episode: number, tmdb_season: 1, tmdb_episode: number,
      tmdb_episode_id: 100 + number, catalogue_title_fr: "Titre #{number}", title_original: "Title #{number}" }
  end

  def snapshot
    { format: 'vidb.tmdb_series_snapshot', version: 1, tmdb_series_id: 75219,
      episodes: [1, 2].map do |number|
        { tmdb_episode_id: 100 + number, season_number: 1, episode_number: number,
          title_fr: "Titre #{number}", title_original: "Title #{number}" }
      end }
  end
end
