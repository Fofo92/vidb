require 'test_helper'

class RecordPosters::SeriesSearchSnapshotTest < ActiveSupport::TestCase
  def collect(pages)
    @calls = []
    calls = @calls
    client = Object.new
    client.define_singleton_method(:search) do |title:, page:|
      calls << [title, page]
      value = pages.fetch(page)
      raise value if value.is_a?(Exception)

      value
    end
    RecordPosters::SeriesSearchSnapshot.new(client: client).call(title: 'Série recherchée')
  end

  def page(number, rows, count: 2, total: 2)
    { 'page' => number, 'total_pages' => count, 'total_results' => total,
      'results' => rows.map { |id| { 'id' => id } } }
  end

  test 'a complete 199 result ten page search can be evaluated automatically' do
    pages = (1..10).to_h do |number|
      ids = ((number - 1) * 20 + 1..[number * 20, 199].min).to_a
      [number, page(number, ids, count: 10, total: 199)]
    end
    result = collect(pages)
    assert result[:complete]
    assert_equal 199, result[:results].size
    assert_equal (1..10).to_a, @calls.map(&:last)
  end

  test 'duplicates missing rows changing totals and wrong page numbers block acceptance' do
    [page(2, [1]), page(2, []), page(2, [2], total: 3), page(1, [2])].each do |second|
      result = collect(1 => page(1, [1]), 2 => second)
      assert_not result[:complete]
      assert_empty result[:results]
    end
  end

  test 'searches beyond the bounded page limit remain unresolved without truncation' do
    result = collect(1 => page(1, [1], count: 21, total: 401))
    assert_not result[:complete]
    assert_equal [['Série recherchée', 1]], @calls
  end

  test 'an empty complete search returns no candidates' do
    result = collect(1 => page(1, [], count: 0, total: 0))
    assert result[:complete]
    assert_empty result[:results]
  end

  test 'a failed later page cannot produce a partial accepted result' do
    assert_raises(CatalogEnrichment::TmdbClient::Error) do
      collect(1 => page(1, [1]), 2 => CatalogEnrichment::TmdbClient::Error.new('temporary failure'))
    end
  end
end
