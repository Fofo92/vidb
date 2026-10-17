# frozen_string_literal: true
require 'test_helper'
require 'tmpdir'
class TmdbFilmClientTest < ActiveSupport::TestCase
  Response = Struct.new(:code, :body)
  test 'search encodes titles and caches each query independently without credentials' do
    Dir.mktmpdir do |directory|
      calls=[]
      transport=->(uri,headers) { calls << [uri,headers]; Response.new('200',JSON.generate(page:1,total_pages:1,results:[])) }
      client=CatalogEnrichment::TmdbFilmClient.new(cache_dir:directory,token:'private-token',transport:transport)
      client.search(title:'L’été & nous ?');client.search(title:'Autre film');client.search(title:'L’été & nous ?')
      assert_equal 2,calls.size
      assert_equal 'L’été & nous ?',URI.decode_www_form(calls.first.first.query).to_h['query']
      assert_equal 'Bearer private-token',calls.first.last['Authorization']
      assert Dir["#{directory}/*.json"].all? { |file| !File.read(file).include?('private-token') }
    end
  end
  test 'movie id must agree with the requested details' do
    Dir.mktmpdir do |directory|
      client=CatalogEnrichment::TmdbFilmClient.new(cache_dir:directory,token:'token',transport:->(*) { Response.new('200','{"id":2}') })
      assert_raises(CatalogEnrichment::TmdbClient::Error) { client.movie(id:1) }
    end
  end
  test 'query injection and unexpected endpoints are refused before transport' do
    client=CatalogEnrichment::TmdbFilmClient.new(cache_dir:'unused',token:'token',transport:->(*) { flunk })
    ['../movie/1','search/movie?query=Film&api_key=bad&page=1','movie/1?api_key=bad','tv/1'].each do |path|
      assert_raises(ArgumentError) { client.get(path) }
    end
    assert_raises(ArgumentError) { client.search(title:"bad\nname") }
    assert_raises(ArgumentError) { client.movie(id:'1') }
  end
  test 'HTTP 429 is not cached and secrets are not echoed' do
    Dir.mktmpdir do |directory|
      client=CatalogEnrichment::TmdbFilmClient.new(cache_dir:directory,token:'private-token',transport:->(*) { Response.new('429','private-token') })
      error=assert_raises(CatalogEnrichment::TmdbClient::Error) { client.search(title:'Film') }
      assert_not_includes error.message,'private-token'
      assert_empty Dir["#{directory}/*"]
    end
  end
  test 'API key remains supported without writing it into payloads' do
    Dir.mktmpdir do |directory|
      transport=->(uri,headers) do
        assert_equal 'key',URI.decode_www_form(uri.query).to_h['api_key']
        assert_nil headers['Authorization']
        Response.new('200','{"id":1}')
      end
      client=CatalogEnrichment::TmdbFilmClient.new(cache_dir:directory,token:nil,api_key:'key',transport:transport)
      assert_equal 1,client.movie(id:1)['id']
    end
  end
end

class TmdbFilmClientTest
  test 'later search pages have independent cache keys and preserve requested page' do
    Dir.mktmpdir do |directory|
      calls=[]
      transport=->(uri,*) do
        page=URI.decode_www_form(uri.query).to_h['page'].to_i
        calls<<page
        Response.new('200',JSON.generate(page:page,total_pages:2,results:[]))
      end
      client=CatalogEnrichment::TmdbFilmClient.new(cache_dir:directory,token:'token',transport:transport)
      client.search(title:'Titre',page:1);client.search(title:'Titre',page:2);client.search(title:'Titre',page:2)
      assert_equal [1,2],calls
      assert_raises(ArgumentError) { client.search(title:'Titre',page:0) }
    end
  end
  test 'release dates retain authenticated transport and require matching identity' do
    Dir.mktmpdir do |directory|
      transport=->(uri,*) do
        assert_equal '/3/movie/42/release_dates',uri.path
        Response.new('200','{"id":42,"results":[]}')
      end
      client=CatalogEnrichment::TmdbFilmClient.new(cache_dir:directory,token:'token',transport:transport)
      assert_equal 42,client.release_dates(id:42)['id']
    end
  end
end
