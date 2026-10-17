# frozen_string_literal: true
require 'test_helper'
class FilmReleaseReferenceTest < ActiveSupport::TestCase
  setup do
    @movie={'id'=>42,'release_date'=>'2022-03-01'}
    @reference=CatalogEnrichment::FilmReleaseReference.new
  end
  def dates(*events)
    {'id'=>42,'results'=>[{'iso_3166_1'=>'FR','release_dates'=>events.map { |type,date|{'type'=>type,'release_date'=>date} }}]}
  end
  test 'first public premiere year is retained rather than a later theatrical year' do
    result=@reference.call(movie:@movie,release_dates:dates([1,'2021-09-01T00:00:00.000Z'],[3,'2022-03-01T00:00:00.000Z']))
    assert_equal '2021-09-01',result['release_date']
    assert_equal '2022-03-01',result.dig('_vidb_release_evidence',:primary_release_date)
    assert_equal [2021,2022],result.dig('_vidb_release_evidence',:observed_release_years)
  end
  test 'physical editions never become first diffusion evidence' do
    result=@reference.call(movie:@movie,release_dates:dates([5,'2020-01-01'],[6,'2021-01-01']))
    assert_equal '2021-01-01',result['release_date']
    assert_equal 6,result.dig('_vidb_release_evidence',:selected,:type)
  end
  test 'absence of public dates does not fall back to the basic date' do
    result=@reference.call(movie:@movie,release_dates:dates([5,'2020-01-01']))
    assert_nil result['release_date']
    assert_nil result.dig('_vidb_release_evidence',:selected)
  end
  test 'wrong film dates are refused' do
    assert_raises(ArgumentError) { @reference.call(movie:@movie,release_dates:dates.merge('id'=>99)) }
  end
  test 'invalid future and pre catalogue dates do not qualify an old year' do
    result=@reference.call(movie:@movie,release_dates:dates([1,'2022-02-31'],[3,'2999-01-01'],[3,'1890-01-01']))
    assert_nil result['release_date']
  end
  test 'the source movie and response remain unchanged' do
    original=@movie.deep_dup;events=dates([3,'2021-01-01']);before=events.deep_dup
    @reference.call(movie:@movie,release_dates:events)
    assert_equal original,@movie
    assert_equal before,events
  end
end
