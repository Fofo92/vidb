# frozen_string_literal: true

require 'test_helper'
require 'tmpdir'

class TmdbClientTest < ActiveSupport::TestCase
  Response = Struct.new(:code, :body)

  test 'bearer authentication and cache avoid repeated network requests and secret persistence' do
    Dir.mktmpdir do |directory|
      calls = []
      transport = lambda do |uri, headers|
        calls << [uri, headers]
        Response.new('200', '{"id":790,"name":"Poirot"}')
      end
      client = CatalogEnrichment::TmdbClient.new(cache_dir: directory, token: 'secret-token', transport: transport)
      assert_equal 790, client.get('tv/790')['id']
      assert_equal 790, client.get('tv/790')['id']
      assert_equal 1, calls.length
      assert_equal 'Bearer secret-token', calls.first.last['Authorization']
      assert_not_includes calls.first.first.to_s, 'secret-token'
      assert_not_includes File.read(Dir["#{directory}/*.json"].first), 'secret-token'
    end
  end

  test 'HTTP errors do not cache response bodies or disclose credentials' do
    Dir.mktmpdir do |directory|
      transport = ->(*) { Response.new('401', 'secret-token') }
      client = CatalogEnrichment::TmdbClient.new(cache_dir: directory, token: 'secret-token', transport: transport)
      error = assert_raises(CatalogEnrichment::TmdbClient::Error) { client.get('tv/790') }
      assert_not_includes error.message, 'secret-token'
      assert_empty Dir["#{directory}/*"]
    end
  end

  test 'invalid endpoints are refused before network access' do
    client = CatalogEnrichment::TmdbClient.new(cache_dir: 'unused', token: 'token', transport: ->(*) { flunk })
    assert_raises(ArgumentError) { client.get('../other') }
  end

  test 'API key authentication remains available' do
    Dir.mktmpdir do |directory|
      transport = lambda do |uri, headers|
        assert_equal 'secret-key', URI.decode_www_form(uri.query).to_h['api_key']
        assert_nil headers['Authorization']
        Response.new('200', '{"id":790}')
      end
      client = CatalogEnrichment::TmdbClient.new(
        cache_dir: directory, token: nil, api_key: 'secret-key', transport: transport
      )
      assert_equal 790, client.get('tv/790')['id']
    end
  end
end
