require 'test_helper'

class Tv::LibraryWorkCandidatesTest < ActiveSupport::TestCase
  Row = Struct.new(:id, :record_kind, :french_title, :original_title, :ancestry)
  Programme = Struct.new(:id, :titles, :episode_numbers)

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

    def all
      self
    end

    def select(*)
      self
    end

    def includes(*)
      self
    end
  end

  setup do
    @film = Row.new(42, 'standalone_video', "Harry Potter et le Prisonnier d’Azkaban",
                    'Harry Potter and the Prisoner of Azkaban')
    @programme = Programme.new(7, [{ 'value' => "Harry Potter et le Prisonnier d'Azkaban", 'language' => 'fr' }], [])
  end

  def lookup(extra = [])
    Tv::LibraryWorkCandidates.new(records: Records.new([@film] + extra)).call([@programme])
  end

  test 'finds an unnumbered film by French or original title without interpreting its filename prefix' do
    assert_equal({ 7 => @film }, lookup)
    @programme.titles = [{ 'value' => @film.original_title, 'language' => 'en' }]
    assert_equal({ 7 => @film }, lookup)
  end

  test 'does not confuse another Harry Potter film' do
    @programme.titles = [{ 'value' => 'Harry Potter et la Chambre des secrets' }]
    assert_empty lookup
  end

  test 'homonymous films and film series collisions require review rather than a match' do
    assert_empty lookup([Row.new(43, 'standalone_video', @film.french_title, nil)])
    assert_empty lookup([Row.new(43, 'series', @film.french_title, nil)])
  end

  test 'does not reinterpret an episode or malformed numbering as an autonomous film' do
    @programme.episode_numbers = [{ 'system' => 'xmltv_ns', 'value' => '0.0.' }]
    assert_empty lookup
    @programme.episode_numbers = [{ 'system' => 'onscreen', 'value' => 'S01 E01' }]
    assert_empty lookup
  end

  test 'includes individual works with an undetermined kind but excludes containers' do
    @film.record_kind = 'undetermined'
    assert_equal({ 7 => @film }, lookup)
    @film.record_kind = 'collection'
    assert_empty lookup
  end
  test 'a legacy parent with an undetermined kind is not an individual work' do
    @film.record_kind = 'undetermined'
    child = Row.new(43, 'undetermined', 'Autre œuvre', nil, '42')
    assert_empty lookup([child])
  end

  test 'an individual documentary or episode can be recognized without a film classification' do
    %w[undetermined standalone_video episode].each do |kind|
      @film.record_kind = kind
      assert_equal({ 7 => @film }, lookup)
    end
  end

end
