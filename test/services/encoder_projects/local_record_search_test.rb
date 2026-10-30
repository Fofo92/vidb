require 'test_helper'

class EncoderProjects::LocalRecordSearchTest < ActiveSupport::TestCase
  Row = Struct.new(:id, :french_title, :original_title)

  class Records
    def initialize(rows)
      @rows = rows
    end

    def select(*)
      self
    end

    def find_each(&)
      @rows.sort_by(&:id).each(&)
    end

    def where(id:)
      self.class.new(@rows.select { |row| Array(id).include?(row.id) })
    end

    def order(*)
      self.class.new(@rows.sort_by { |row| [row.french_title, row.id] })
    end

    def to_a
      @rows
    end
  end

  setup do
    @record = Row.new(12, "États-Unis : la fuite des cerveaux vers l’Europe", 'Brain drain')
    @other = Row.new(13, 'Une autre œuvre', '')
    @rows = [@record, @other]
    @search = EncoderProjects::LocalRecordSearch.new(records: Records.new(@rows))
  end

  test 'local titles ignore accents punctuation and case' do
    assert_equal [@record], @search.call("Etats-Unis : la fuite des cerveaux vers l'Europe", host: 'vidb.test')
    assert_equal [@record], @search.call('fuite cerveaux', host: 'vidb.test')
    assert_equal [@record], @search.call('BRAIN DRAIN', host: 'vidb.test')
  end

  test 'a record created between requests becomes visible on refresh' do
    assert_empty @search.call('Documentaire nouveau', host: 'vidb.test')
    fresh = Row.new(14, 'Documentaire nouveau', '')
    @rows << fresh
    assert_equal [fresh], @search.call('Documentaire nouveau', host: 'vidb.test')
  end

  test 'ids and local links select one exact record' do
    ['12', '#12', '/records/12', 'https://vidb.test/records/12?foo=1'].each do |query|
      assert_equal [@record], @search.call(query, host: 'vidb.test')
    end
    assert_empty @search.call('https://foreign.test/records/12', host: 'vidb.test')
  end

  test 'empty or missing identities never list the complete catalogue' do
    assert_empty @search.call('', host: 'vidb.test')
    assert_empty @search.call('9999', host: 'vidb.test')
    assert_empty @search.call('titre inconnu', host: 'vidb.test')
  end

  test 'homonyms stay separate and the result count is bounded' do
    rows = (1..60).map { |id| Row.new(id, 'Documentaire', '') }
    search = EncoderProjects::LocalRecordSearch.new(records: Records.new(rows))
    result = search.call('Documentaire', host: 'vidb.test')
    assert_equal 50, result.size
    assert_equal 50, result.map(&:id).uniq.size
  end
end
