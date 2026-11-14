require 'test_helper'

class RecordPosters::FilmSearchTest < ActiveSupport::TestCase
  SUMMARY = 'Avril 1945 les Alliés offensive Europe tank Sherman sergent Wardaddy mission dangereuse ' \
            'Allemagne nazie'.freeze

  def local
    { 'french_title' => 'Fury', 'original_title' => 'Fury', 'year' => 2014, 'abstract' => SUMMARY }
  end

  def movie(id)
    { 'id' => id, 'title' => 'Fury', 'original_title' => 'Fury',
      'release_date' => '2014-10-15', 'overview' => SUMMARY }
  end

  def client(rows, pages: 1)
    requests = []
    object = Object.new
    object.define_singleton_method(:search_for_year) do |title:, year:, page:|
      requests << [title, year, page]
      { 'page' => page, 'total_pages' => pages, 'results' => rows }
    end
    object.define_singleton_method(:search) do |title:, page:|
      requests << [title, nil, page]
      { 'page' => page, 'total_pages' => 21, 'results' => [] }
    end
    [object, requests]
  end

  test 'a complete year search resolves Fury without scanning broad unrelated results' do
    source, requests = client([movie(228150)])
    snapshot = RecordPosters::FilmSearch.new(client: source).call(local: local)
    assert snapshot[:complete]
    assert_equal [['Fury', 2014, 1]], requests
    result = RecordPosters::FilmPosterComparison.new.call(local: local, results: snapshot[:results])
    assert_equal 228150, result[:tmdb_id]
  end

  test 'two supported films in the same year remain ambiguous' do
    source, = client([movie(1), movie(2)])
    snapshot = RecordPosters::FilmSearch.new(client: source).call(local: local)
    result = RecordPosters::FilmPosterComparison.new.call(local: local, results: snapshot[:results])
    assert_not_equal 'candidate', result[:status]
  end

  test 'an incomplete scoped search never confirms a candidate' do
    source, requests = client([movie(1)], pages: 21)
    snapshot = RecordPosters::FilmSearch.new(client: source).call(local: local)
    assert_not snapshot[:complete]
    assert requests.any? { |request| request[1].nil? }
  end

  test 'empty scoped results fall back to the broad search' do
    source, requests = client([])
    RecordPosters::FilmSearch.new(client: source).call(local: local)
    assert requests.any? { |request| request[1].nil? }
  end

  test 'release year queries reject duplicate or unexpected parameters' do
    source = CatalogEnrichment::TmdbFilmClient.new(cache_dir: Rails.root.join('tmp/test-film-year'))
    query = 'query=Fury&include_adult=false&page=1&primary_release_year=2014'
    assert source.send(:valid_query?, query)
    assert_not source.send(:valid_query?, "#{query}&primary_release_year=2015")
    assert_not source.send(:valid_query?, "#{query}&extra=1")
    assert_not source.send(:valid_query?, query.sub('2014', 'oops'))
  end
end
