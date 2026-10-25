require 'test_helper'

class EncoderProjects::MissingSeriesCatalogueTest < ActiveSupport::TestCase
  Numbers = Struct.new(:season, :episode, :title)

  class References
    def self.genres(*) = [20]
    def self.countries(*) = [13]
  end

  test 'looks up a new series externally without needing a local record' do
    client = Object.new
    client.define_singleton_method(:search) { |title:| { 'results' => [{ 'id' => 4057, 'name' => title }] } }
    client.define_singleton_method(:get) do |path, language: nil|
      if path.include?('/season/')
        { 'episodes' => [{ 'id' => 101, 'episode_number' => 22, 'name' => 'Chambre noire',
                          'air_date' => '2011-05-04', 'overview' => 'Une enquête.' }] }
      else
        { 'id' => 4057, 'name' => 'Esprits criminels', 'original_name' => 'Criminal Minds',
          'first_air_date' => '2005-09-22', 'genres' => [], 'origin_country' => ['US'],
          'seasons' => [{ 'season_number' => 6, 'episode_count' => 24 }] }
      end
    end
    wiki = Object.new
    wiki.define_singleton_method(:search_series) { |_title| [] }
    service = EncoderProjects::MissingSeriesCatalogue.new(tmdb: client, wikipedia: wiki, references: References)
    rows = service.call('Esprits criminels', Numbers.new(6, 22, 'Chambre noire'))
    assert_equal 1, rows.size
    assert_equal 'Chambre noire', rows.first['title']
    assert_equal 4057, rows.first.dig('series_candidate', 'tmdb_id')
    assert_equal 24, rows.first.dig('series_candidate', 'episode_count')
    assert_equal 'tmdb:4057', rows.first['series_id']
  end

  test 'French vowel series names use the elided Wikipedia season title' do
    assert_equal "Saison 6 d'Esprits criminels", EncoderProjects::WikipediaSeasonTitle.call('Esprits criminels', 6)
    assert_equal "Saison 2 de Cat's Eyes", EncoderProjects::WikipediaSeasonTitle.call("Cat's Eyes", 2)
  end
end
