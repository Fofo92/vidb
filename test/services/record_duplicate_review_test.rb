require 'test_helper'

class RecordDuplicateReviewTest < ActiveSupport::TestCase
  Item = Struct.new(:id, :record_kind, :french_title, :original_title, :year, :rank, :ancestor_ids)
  Copy = Struct.new(:record_id)

  def item(id, title = 'Jo', kind: 'standalone_video', year: 1971, rank: nil, parents: [])
    Item.new(id, kind, title, '', year, rank, parents)
  end

  def groups(records, assets = [])
    RecordDuplicateReview.new(records: records, assets: assets).call
  end

  test 'two records of one work are reported with their respective copies' do
    rows = groups([item(1), item(2, 'JO')], [Copy.new(1), Copy.new(2)])
    assert_equal 1, rows.size
    assert_equal [1, 2], rows.first[:records].map(&:id)
    assert_equal 1, rows.first[:copies].fetch(1).size
  end

  test 'two files belonging to one record are not two logical records' do
    assert_empty groups([item(1)], [Copy.new(1), Copy.new(1)])
  end

  test 'different years or natures are not grouped' do
    assert_empty groups([item(1), item(2, year: 2020), item(3, kind: 'series')])
  end

  test 'identically named seasons from different series are not duplicates' do
    records = [item(1, 'Friends', kind: 'series'), item(2, 'Jo', kind: 'series'),
               item(3, 'Saison 01', kind: 'season', parents: [1]),
               item(4, 'Saison 01', kind: 'season', parents: [2])]
    assert_empty groups(records)
  end

  test 'duplicate episodes under duplicated series retain their context and rank' do
    records = [item(1, 'Friends', kind: 'series'), item(2, 'Friends', kind: 'series'),
               item(3, 'Pilot', kind: 'episode', rank: 1, parents: [1]),
               item(4, 'Pilot', kind: 'episode', rank: 1, parents: [2])]
    assert_equal [[1, 2], [3, 4]], groups(records).map { |row| row[:records].map(&:id) }
  end

  test 'episode years identify same-title series even without any video files' do
    records = [item(1, 'Einstein', kind: 'series', year: nil),
               item(2, 'Einstein', kind: 'series', year: nil),
               item(3, 'Einstein', kind: 'series', year: nil),
               item(4, 'Saison 01', kind: 'season', year: nil, parents: [1]),
               item(5, 'Second', kind: 'episode', year: 2018, parents: [1, 4]),
               item(6, 'Pilot', kind: 'episode', year: 2017, parents: [1, 4]),
               item(7, 'Other pilot', kind: 'episode', year: 2017, parents: [2]),
               item(8, 'Remake pilot', kind: 'episode', year: 2024, parents: [3])]

    group = groups(records).sole
    assert_equal [1, 2], group[:records].map(&:id)
    assert_equal({ 1 => 2017, 2 => 2017 }, group[:years])
    assert_equal({ 1 => [], 2 => [] }, group[:copies])
  end

  test 'two unknown years do not count as a matching year' do
    assert_empty groups([item(1, year: nil), item(2, year: nil)])
  end

  test 'films inside and outside a collection can still be duplicates' do
    assert_equal 1, groups([item(1, parents: [99]), item(2)]).size
  end

  test 'different episode ranks are not grouped' do
    parent = item(1, 'Friends', kind: 'series')
    assert_empty groups([parent, item(2, 'Pilot', kind: 'episode', rank: 1, parents: [1]),
                        item(3, 'Pilot', kind: 'episode', rank: 2, parents: [1])])
  end
end
