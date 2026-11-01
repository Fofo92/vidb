require 'test_helper'
require 'minitest/mock'

class RecordPosters::CollectionPlanTest < ActiveSupport::TestCase
  Item = Struct.new(:record_kind, :french_title, :original_title, :children, :year_evidence,
                    :abstract_provenance, :genre_provenance, :record_poster) do
    def has_children?
      children.any?
    end
  end

  def film(id)
    Item.new('standalone_video', 'Film', '', [], { 'tmdb_movie_id' => id }, {}, {}, nil)
  end

  def collection(children = [film(1), film(2)])
    Item.new('collection', 'James Bond', '', children, {}, {}, {}, nil)
  end

  def client(membership = { 'id' => 645 })
    Object.new.tap do |api|
      api.define_singleton_method(:movie) { |_id| { 'belongs_to_collection' => membership } }
      api.define_singleton_method(:collection) do |id|
        { 'id' => id, 'name' => 'James Bond - Saga', 'parts' => [{ 'id' => 1 }, { 'id' => 2 }] }
      end
    end
  end

  test 'two distinct identified children and concordant title establish a candidate without writing' do
    item = collection
    before = item.to_h.deep_dup
    plan = RecordPosters::CollectionPlan.new(client: client).call(item)
    assert_equal 'ready', plan[:status]
    assert_equal 645, plan[:target]
    assert_equal [1, 2], plan[:movies]
    assert_equal before, item.to_h
  end

  test 'one film or duplicate copies of one film do not establish a collection' do
    [[film(1)], [film(1), film(1)]].each do |children|
      assert_equal 'review', RecordPosters::CollectionPlan.new(client: client).call(collection(children))[:status]
    end
  end

  test 'a single unidentified child blocks inference' do
    assert_equal 'review', RecordPosters::CollectionPlan.new(client: client).call(collection([film(1), film(nil)]))[:status]
  end

  test 'missing membership does not create a collection identity' do
    assert_equal 'review', RecordPosters::CollectionPlan.new(client: client(nil)).call(collection)[:status]
  end

  test 'different collection memberships remain for review' do
    api = client
    api.define_singleton_method(:movie) { |id| { 'belongs_to_collection' => { 'id' => id } } }
    assert_equal 'review', RecordPosters::CollectionPlan.new(client: api).call(collection)[:status]
  end

  test 'a personal grouping name does not acquire a franchise poster automatically' do
    item = collection
    item.french_title = 'Mes films préférés'
    assert_equal 'review', RecordPosters::CollectionPlan.new(client: client).call(item)[:status]
  end

  test 'collection catalogue must confirm all film memberships' do
    api = client
    api.define_singleton_method(:collection) { |id| { 'id' => id, 'name' => 'James Bond', 'parts' => [{ 'id' => 1 }] } }
    assert_equal 'review', RecordPosters::CollectionPlan.new(client: api).call(collection)[:status]
  end

  test 'existing explicit identity is reused even with a local title variant' do
    item = collection
    item.french_title = '007'
    item.year_evidence = { 'tmdb_collection_id' => 645 }
    assert_equal 'identified', RecordPosters::CollectionPlan.new(client: client).call(item)[:status]
  end

  test 'contradictory explicit references block import' do
    item = collection
    item.year_evidence = { 'tmdb_collection_id' => 645 }
    item.genre_provenance = { 'tmdb_collection_id' => 2467 }
    assert_equal 'review', RecordPosters::CollectionPlan.new(client: client).call(item)[:status]
  end

  test 'manual poster suppression is preserved without API requests' do
    item = collection
    item.record_poster = Struct.new(:source, :image).new({ 'kind' => 'manual' }, nil)
    assert_equal 'preserved', RecordPosters::CollectionPlan.new(client: Object.new).call(item)[:status]
  end

  test 'nested collections are reported without flattening the hierarchy' do
    assert_equal 'review', RecordPosters::CollectionPlan.new(client: client).call(collection([collection]))[:status]
  end
end
