require 'test_helper'
require 'tmpdir'

class EncoderProjects::TmdbSeriesClientTest < ActiveSupport::TestCase
  test 'searches television with a bounded query through the authenticated client' do
    Dir.mktmpdir do |directory|
      observed = nil
      transport = lambda do |uri, headers|
        observed = [uri, headers]
        Struct.new(:code, :body).new('200', JSON.generate('page' => 1, 'results' => []))
      end
      client = EncoderProjects::TmdbSeriesClient.new(cache_dir: directory, token: 'fake', transport: transport)
      assert_equal [], client.search(title: "Cat's Eyes")['results']
      assert_equal '/3/search/tv', observed.first.path
      assert_equal "Cat's Eyes", URI.decode_www_form(observed.first.query).to_h['query']
      assert_equal 'Bearer fake', observed.last['Authorization']
    end
  end

  test 'rejects invalid paths and queries before invoking a transport' do
    Dir.mktmpdir do |directory|
      transport = ->(*) { raise 'unexpected network request' }
      client = EncoderProjects::TmdbSeriesClient.new(cache_dir: directory, token: 'fake', transport: transport)
      assert_raises(ArgumentError) { client.search(title: '') }
      assert_raises(ArgumentError) { client.get('search/tv?query=Film&include_adult=false&page=2') }
      assert_raises(ArgumentError) { client.get('movie/7') }
    end
  end
  test 'fetches an exact episode through the authenticated client' do
    Dir.mktmpdir do |directory|
      observed = nil
      transport = lambda do |uri, _headers|
        observed = uri
        Struct.new(:code, :body).new('200', JSON.generate('id' => 987, 'season_number' => 14, 'episode_number' => 2))
      end
      client = EncoderProjects::TmdbSeriesClient.new(cache_dir: directory, token: 'fake', transport: transport)
      assert_equal 987, client.get('tv/42083/season/14/episode/2')['id']
      assert_equal '/3/tv/42083/season/14/episode/2', observed.path
      assert_raises(ArgumentError) { client.get('tv/42083/season/14/episode/0') }
      assert_raises(ArgumentError) { client.get('tv/42083/season/14/episode/2/credits') }
    end
  end

end
