# frozen_string_literal: true

require 'test_helper'

class TmdbSeriesSnapshotTest < ActiveSupport::TestCase
  test 'retrieves translated and original titles without treating air dates as production years' do
    calls = []
    client = Object.new
    client.define_singleton_method(:get) do |path, language: 'fr-FR'|
      calls << [path, language]
      if path == 'tv/790'
        { 'id' => 790, 'original_language' => 'en', 'seasons' => [{ 'season_number' => 0 }, { 'season_number' => 1 }] }
      else
        { 'season_number' => 1, 'episodes' => [{ 'id' => 20, 'episode_number' => 1,
                                              'name' => language == 'en' ? 'The Dream' : 'Le Songe',
                                              'air_date' => '1989-03-19', 'runtime' => 50 }] }
      end
    end
    result = CatalogEnrichment::TmdbSeriesSnapshot.new(client: client, series_id: 790).call
    episode = result[:episodes].first
    assert_equal 'Le Songe', episode[:title_fr]
    assert_equal 'The Dream', episode[:title_original]
    assert_equal '1989-03-19', episode[:first_air_date]
    assert_equal 50, episode[:reference_runtime_minutes]
    assert_not episode.key?(:production_year)
    assert_equal 3, calls.length
    assert result[:read_only]
  end
end
