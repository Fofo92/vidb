require 'test_helper'

class RecordPosters::FilmReviewTest < ActiveSupport::TestCase
  def record(title: 'Film de test', synopsis: 'Une famille part en voyage puis revient dans sa maison')
    Struct.new(:attributes).new({ 'french_title' => title, 'original_title' => nil,
                                 'year' => 2022, 'abstract' => synopsis })
  end

  def review(results, item: record, pages: 1)
    client = Object.new
    client.define_singleton_method(:search) do |title:, page:|
      { 'results' => page == 1 ? results : [], 'page' => page, 'total_pages' => pages }
    end
    RecordPosters::FilmReview.new(client: client).call(item)
  end

  def movie(id: 1, summary: 'Une famille part en voyage puis revient dans sa maison')
    { 'id' => id, 'title' => 'Film de test', 'original_title' => 'Film de test',
      'release_date' => '2022-01-01', 'overview' => summary }
  end

  test 'the review explains missing titles missing synopses and empty searches' do
    assert_match(/titre/, review([], item: record(title: nil))[:message])
    assert_match(/Aucun résultat/, review([])[:message])
    result = review([movie], item: record(synopsis: nil))
    assert_match(/synopsis local manque/, result[:message])
    assert_equal 1, result[:candidates].size
  end

  test 'partial and ambiguous searches never imply a confirmed identity' do
    assert_match(/partielle/, review([movie], pages: 21)[:message])
    assert_match(/Plusieurs références/, review([movie, movie(id: 2)])[:message])
  end

  test 'matching proposals and disagreements are explained separately' do
    assert_match(/concordante/, review([movie])[:message])
    assert_match(/ne suffisent pas/, review([movie(summary: 'Autre sujet entièrement différent')])[:message])
  end

  test 'at most twelve candidates are displayed with their evidence and synopsis' do
    result = review((1..15).map { |id| movie(id: id) })
    assert_equal 12, result[:candidates].size
    candidate = result[:candidates].first
    assert candidate[:overview].present?
    assert candidate[:evidence].key?(:year_compatible)
  end
end
