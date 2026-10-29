require 'test_helper'
require 'minitest/mock'

class EncoderProjects::TmdbEpisodeUrlProposalTest < ActiveSupport::TestCase
  class Client
    attr_reader :calls
    attr_accessor :episode, :series

    def initialize
      @calls = []
      @series = { 'id' => 42083, 'name' => 'Joséphine, ange gardien', 'original_language' => 'fr' }
      @episode = { 'id' => 987, 'season_number' => 14, 'episode_number' => 2,
                   'name' => 'Chasse aux fantômes', 'air_date' => '2010-10-25', 'overview' => 'Résumé', 'runtime' => 90 }
    end

    def get(path, **_options)
      @calls << path
      return @series if path == 'tv/42083'
      raise ArgumentError, "Unexpected request: #{path}" unless path == 'tv/42083/season/14/episode/2'

      @episode
    end
  end

  test 'loads the precise external episode without consulting the local season' do
    client = Client.new
    builder = EncoderProjects::TmdbEpisodeUrlProposal.new(client: client, warnings: [])
    proposal = builder.call(42083, { 'season' => 14, 'episode' => 2 })
    assert_equal ['tv/42083', 'tv/42083/season/14/episode/2'], client.calls
    assert_equal 'Chasse aux fantômes', proposal['title']
    assert_equal 2010, proposal['year']
    assert_equal 90, proposal['reference_runtime_minutes']
    assert_equal 'https://www.themoviedb.org/tv/42083/season/14/episode/2', proposal.dig('source', 'url')
    assert_equal({ 'series_id' => 42083, 'season' => 14, 'episode' => 2, 'episode_id' => 987 },
                 proposal['tmdb_episode_reference'])
    refute proposal.key?('catalogue_completion')
  end

  test 'rejects a changed identity or a response for another episode' do
    client = Client.new
    builder = EncoderProjects::TmdbEpisodeUrlProposal.new(client: client, warnings: [])
    client.episode['episode_number'] = 3
    assert_raises(ArgumentError) { builder.call(42083, { 'season' => 14, 'episode' => 2 }) }
    client.episode['episode_number'] = 2
    assert_raises(ArgumentError) { builder.call(42083, { 'season' => 14, 'episode' => 2, 'episode_id' => 988 }) }
    client.series['id'] = 42
    assert_raises(ArgumentError) { builder.call(42083, { 'season' => 14, 'episode' => 2 }) }
  end
end
