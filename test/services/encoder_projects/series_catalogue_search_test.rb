require 'test_helper'

module EncoderProjects
  class SeriesCatalogueSearchTest < ActiveSupport::TestCase
    def row
      { 'id' => 335_534, 'name' => 'Gerta et le monde déchiré', 'original_name' => 'Gerta Schnirch',
        'first_air_date' => '2026-02-04' }
    end

    test 'a title query returns series identities without requiring episode numbers' do
      item = row
      client = Object.new
      client.define_singleton_method(:search) do |title:|
        raise 'wrong query' unless title == 'Gerta et le monde déchiré'

        { 'results' => [item] }
      end
      result = SeriesCatalogueSearch.new(client: client).call('Gerta et le monde déchiré')
      assert_equal 335_534, result.sole['tmdb_id']
      assert_equal 'Gerta Schnirch', result.sole['original_title']
      assert_equal 2026, result.sole['year']
    end

    test 'a direct TV URL bypasses title search' do
      item = row
      client = Object.new
      client.define_singleton_method(:get) do |path|
        raise 'wrong endpoint' unless path == 'tv/335534'

        item
      end
      result = SeriesCatalogueSearch.new(client: client).call('https://www.themoviedb.org/tv/335534-gerta-schnirch')
      assert_equal 335_534, result.sole['tmdb_id']
    end

    test 'an explicit episode choice works without a numbered capture name' do
      request = EpisodeRequest.new('source_paths' => ['/commun/Gerta.m2t'],
                                   'output_path' => '/videos/Gerta.mkv',
                                   'episode_target' => { 'season' => 1, 'episode' => 2 })
      assert_equal [1, 2], [request.season, request.episode]
    end

    test 'an unnumbered capture alone does not become an episode' do
      assert_not EpisodeRequest.match?('source_paths' => ['/commun/Gerta.m2t'])
    end
  end
end
