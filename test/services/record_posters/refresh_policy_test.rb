require 'test_helper'

class RecordPosters::RefreshPolicyTest < ActiveSupport::TestCase
  def poster(kind:, attached:, pending: nil)
    source = { 'kind' => kind }
    source['encoder_pending'] = pending if pending
    image = Struct.new(:attached?).new(attached)
    Struct.new(:source, :image).new(source, image)
  end

  test 'attached automatic artwork stays preserved unless a confirmed refresh is pending' do
    assert RecordPosters::Fetch.preserved?(poster(kind: 'tmdb', attached: true))
    assert_not RecordPosters::Fetch.preserved?(poster(kind: 'tmdb', attached: true, pending: { 'tmdb_movie_id' => 7 }))
  end

  test 'manual images and manual removals keep their existing protections' do
    [true, false].each do |attached|
      assert RecordPosters::Fetch.preserved?(poster(kind: 'manual', attached: attached, pending: { 'tmdb_movie_id' => 7 }))
    end
    assert RecordPosters::Fetch.preserved?(poster(kind: 'manual', attached: true), restore: true)
    assert_not RecordPosters::Fetch.preserved?(poster(kind: 'manual', attached: false), restore: true)
  end

  test 'missing artwork can be fetched and unknown existing artwork is not overwritten' do
    assert_not RecordPosters::Fetch.preserved?(nil)
    assert_not RecordPosters::Fetch.preserved?(poster(kind: 'catalogue', attached: false))
    assert RecordPosters::Fetch.preserved?(poster(kind: 'unknown', attached: true, pending: { 'tmdb_movie_id' => 7 }))
  end

  test 'poster provenance supplies typed identities without changing editorial evidence' do
    source = { 'kind' => 'catalogue', 'encoder_pending' => { 'tmdb_movie_id' => 7 } }
    record = Struct.new(:year_evidence, :abstract_provenance, :genre_provenance, :record_poster)
                   .new({}, {}, {}, Struct.new(:source).new(source))
    assert_equal [7], RecordPosters::Evidence.ids(record, 'movie')
    assert_empty RecordPosters::Evidence.ids(record, 'tv')
    assert_equal({}, record.year_evidence)
  end
end
