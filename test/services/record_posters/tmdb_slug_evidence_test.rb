require 'test_helper'

class RecordPosters::TmdbSlugEvidenceTest < ActiveSupport::TestCase
  test 'recognizes a collection URL with its public title suffix' do
    reader = RecordPosters::Evidence.new('collection')
    assert_equal [2467], reader.ids('url' => 'https://www.themoviedb.org/collection/2467-tomb-raider-collection')
  end

  test 'recognizes film and series suffixes with query strings and fragments' do
    assert_equal [586810], RecordPosters::Evidence.new('movie').ids(
      'source_url' => 'https://www.themoviedb.org/movie/586810-mars-express?language=fr-FR#images'
    )
    assert_equal [42083], RecordPosters::Evidence.new('tv').ids(
      'source' => 'https://www.themoviedb.org/tv/42083-josephine-ange-gardien/season/14/episode/2'
    )
  end

  test 'rejects a foreign host and preserves typed namespaces' do
    reader = RecordPosters::Evidence.new('collection')
    assert_empty reader.ids('url' => 'https://www.themoviedb.org.evil.test/collection/2467-tomb-raider')
    assert_empty reader.ids('url' => 'https://www.themoviedb.org/movie/2467-tomb-raider')
    assert_empty reader.ids('url' => 'https://www.themoviedb.org/collection/2467garbage')
  end

  test 'keeps conflicting identities visible for manual review' do
    assert_equal [999, 2467], RecordPosters::Evidence.new('collection').ids(
      'url' => 'https://www.themoviedb.org/collection/2467-tomb-raider', 'tmdb_collection_id' => 999
    ).sort
  end
end
