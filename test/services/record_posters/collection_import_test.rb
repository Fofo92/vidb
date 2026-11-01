require 'test_helper'
require 'minitest/mock'

class RecordPosters::CollectionImportTest < ActiveSupport::TestCase
  Poster = Struct.new(:source, :image) do
    def with_lock
      yield
    end

    def update!(source:)
      self.source = source
    end
  end
  Owner = Struct.new(:id) do
    def with_lock
      yield
    end

    def reload
      self
    end
  end

  test 'apply stores poster-only evidence then downloads the artwork' do
    plan = { status: 'ready', target: 645, movies: [1, 2] }
    importer = RecordPosters::CollectionImport.new(client: Object.new, fetcher: ->(_record) { :attached })
    importer.instance_variable_set(:@planner, ->(_record) { plan })
    poster = Poster.new({}, Struct.new(:attached?).new(false))
    record = Owner.new(69)
    RecordPoster.stub(:create_or_find_by!, poster) do
      result = importer.call(record, expected: plan)
      assert_equal 'associated', result[:status]
      assert_equal :attached, result[:poster]
      assert_equal 645, poster.source['tmdb_collection_id']
      assert_equal [1, 2], poster.source.dig('collection_inference', 'movie_ids')
      assert_equal 69, record.id
    end
  end

  test 'a changed plan does not write a poster or fetch an image' do
    importer = RecordPosters::CollectionImport.new(client: Object.new, fetcher: ->(_record) { flunk 'download forbidden' })
    importer.instance_variable_set(:@planner, ->(_record) { { status: 'ready', target: 2467 } })
    result = importer.call(Owner.new(69), expected: { status: 'ready', target: 645 })
    assert_equal 'changed', result[:status]
  end

  test 'manual artwork added after planning is preserved under poster lock' do
    plan = { status: 'ready', target: 645, movies: [1, 2] }
    importer = RecordPosters::CollectionImport.new(client: Object.new, fetcher: ->(_record) { flunk 'download forbidden' })
    importer.instance_variable_set(:@planner, ->(_record) { plan })
    poster = Poster.new({ 'kind' => 'manual' }, nil)
    RecordPoster.stub(:create_or_find_by!, poster) do
      assert_equal 'preserved', importer.call(Owner.new(69), expected: plan)[:status]
      assert_equal({ 'kind' => 'manual' }, poster.source)
    end
  end
end
