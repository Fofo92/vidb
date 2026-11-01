require 'test_helper'
require 'minitest/mock'

class RecordPosters::CollectionClientTest < ActiveSupport::TestCase
  def client
    RecordPosters::CollectionClient.new(cache_dir: '/unused-collection-test-cache')
  end

  test 'reads membership from the exact identified movie' do
    payload = { 'id' => 123, 'belongs_to_collection' => { 'id' => 645 } }
    client.stub(:get, payload) { |api| assert_equal payload, api.movie(123) }
  end

  test 'rejects a movie response referring to another identity' do
    client.stub(:get, { 'id' => 999 }) do |api|
      assert_raises(CatalogEnrichment::TmdbClient::Error) { api.movie(123) }
    end
  end

  test 'requires the collection catalogue before inferring an association' do
    client.stub(:get, { 'id' => 645 }) do |api|
      assert_raises(CatalogEnrichment::TmdbClient::Error) { api.collection(645) }
    end
  end
end
