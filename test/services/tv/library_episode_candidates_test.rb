require 'test_helper'

class Tv::LibraryEpisodeCandidatesTest < ActiveSupport::TestCase
  Row = Struct.new(:id, :record_kind, :ancestry, :rank, :french_title, :original_title)
  Programme = Struct.new(:id, :titles, :episode_numbers, :subtitles)

  class Records
    include Enumerable

    def initialize(rows)
      @rows = rows
    end

    def each(&block)
      @rows.each(&block)
    end

    def where(**conditions)
      self.class.new(@rows.select { |row| conditions.all? { |key, values| Array(values).include?(row.public_send(key)) } })
    end

    def select(*)
      self
    end

    def includes(*)
      self
    end
  end

  setup do
    @root = Row.new(10, 'series', nil, nil, 'Joséphine, ange gardien', nil)
    @season = Row.new(20, 'season', '10', 12, 'Saison 12', nil)
    @episode = Row.new(30, 'episode', '10/20', 11, 'Chasse aux fantômes', nil)
    @programme = Programme.new(7, [{ 'value' => 'Joséphine, ange gardien - Saison 12' }],
                               [{ 'system' => 'xmltv_ns', 'value' => '11.10.' }],
                               [{ 'value' => 'Chasse aux fantômes' }])
  end

  def lookup(extra = [])
    detector = Tv::LibraryEpisodeCandidates.new(records: Records.new([@root, @season, @episode] + extra))
    detector.call([@programme])
  end

  test 'matches the qualified hierarchy and its zero based XMLTV numbers' do
    assert_equal({ 7 => @episode }, lookup)
    @root.ancestry = '1'
    @season.ancestry = '1/10'
    @episode.ancestry = '1/10/20'
    assert_equal({ 7 => @episode }, lookup)
  end

  test 'does not collapse homonymous series duplicate seasons or duplicate episode ranks' do
    assert_empty lookup([Row.new(11, 'series', nil, nil, @root.french_title, nil)])
    assert_empty lookup([Row.new(21, 'season', '10', 12, 'Autre saison', nil)])
    assert_empty lookup([Row.new(31, 'episode', '10/20', 11, @episode.french_title, nil)])
  end

  test 'rejects another episode or a contradictory subtitle' do
    @episode.rank = 10
    assert_empty lookup
    @episode.rank = 11
    @episode.french_title = 'Un autre épisode'
    assert_empty lookup
  end

  test 'does not treat unqualified placements or a series flag as an episode acquisition' do
    @season.record_kind = 'undetermined'
    assert_empty lookup
    @season.record_kind = 'season'
    @episode.record_kind = 'series'
    assert_empty lookup
  end
end
