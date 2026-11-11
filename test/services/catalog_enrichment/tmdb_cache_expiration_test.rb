require 'test_helper'
require 'tmpdir'

class CatalogEnrichment::TmdbCacheExpirationTest < ActiveSupport::TestCase
  test 'poster metadata can be refreshed after a bounded cache lifetime' do
    Dir.mktmpdir do |directory|
      calls = 0
      transport = lambda do |*_args|
        calls += 1
        Struct.new(:code, :body).new('200', JSON.generate(id: 700, poster_path: calls == 1 ? nil : '/available.jpg'))
      end
      client = CatalogEnrichment::TmdbClient.new(cache_dir: directory, token: 'test-token',
                                                transport: transport, max_age: 60)
      assert_nil client.get('tv/700')['poster_path']
      assert_nil client.get('tv/700')['poster_path']
      assert_equal 1, calls
      expired_at = 2.minutes.ago.to_time
      Dir.glob("#{directory}/*.json").each { |path| File.utime(expired_at, expired_at, path) }
      assert_equal '/available.jpg', client.get('tv/700')['poster_path']
      assert_equal 2, calls
    end
  end
end
