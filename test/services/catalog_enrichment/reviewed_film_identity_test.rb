# frozen_string_literal: true
require 'test_helper'

class ReviewedFilmIdentityTest < ActiveSupport::TestCase
  setup do
    @local = { 'french_title' => 'Film témoin !', 'original_title' => '', 'abstract' => 'Aymé rencontre Elena.' }
    @movie = { 'id' => 42, 'title' => 'Film temoin', 'original_title' => '', 'overview' => 'Elena aide Aymé.' }
    @review = { 'tmdb_id' => 42, 'anchors' => %w[ayme elena], 'reason' => 'Personnages et récit vérifiés.' }
    @service = CatalogEnrichment::ReviewedFilmIdentity.new
  end
  def decide
    @service.call(local: @local, movie: @movie, review: @review)
  end
  test 'reviewed identity accepts accents punctuation and reordered synopsis' do
    assert_equal true, decide[:supported]
    assert_equal %w[ayme elena], decide[:shared_anchors]
  end
  test 'another numeric identity is refused' do
    @movie['id'] = 43
    assert_raises(ArgumentError) { decide }
  end
  test 'a title without an exact normalized match is refused' do
    @movie['title'] = 'Autre film'
    assert_raises(ArgumentError) { decide }
  end
  test 'missing evidence in either synopsis is refused' do
    @movie['overview'] = 'Elena seule.'
    assert_raises(ArgumentError) { decide }
    @movie['overview'] = 'Elena aide Aymé.'
    @local['abstract'] = 'Aymé seul.'
    assert_raises(ArgumentError) { decide }
  end
  test 'partial words and missing synopsis are refused' do
    @movie['overview'] = 'Elena et Aymette.'
    assert_raises(ArgumentError) { decide }
    @movie['overview'] = nil
    assert_raises(ArgumentError) { decide }
  end
  test 'an unnormalized or insufficient anchor set is refused' do
    @review['anchors'] = ['ayme']
    assert_raises(ArgumentError) { decide }
    @review['anchors'] = ['Aymé', 'elena']
    assert_raises(ArgumentError) { decide }
  end
end
