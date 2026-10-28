require 'test_helper'
require 'minitest/mock'

class EncoderSeriesOriginalLanguageTest < ActiveSupport::TestCase
  Node = Struct.new(:id, :record_kind, :french_title, :original_title, :year, :parent, keyword_init: true) do
    def subtree
      self
    end

    def select(_column)
      [id]
    end
  end

  Links = Struct.new(:ids) do
    def where(**_criteria)
      self
    end

    def distinct
      self
    end

    def limit(_count)
      self
    end

    def pluck(_column)
      ids
    end
  end

  setup do
    @series = Node.new(id: 1, record_kind: 'series', french_title: 'Joséphine, ange gardien', year: 1997)
    @season = Node.new(id: 2, record_kind: 'season', year: 2006, parent: @series)
    @episode = Node.new(id: 3, record_kind: 'episode', french_title: 'Coupée du monde', year: 2006, parent: @season)
    @data = { 'id' => 123, 'name' => 'Joséphine, ange gardien', 'original_name' => 'Joséphine, ange gardien',
              'first_air_date' => '1997-12-15', 'original_language' => 'fr',
              'languages' => ['fr'], 'spoken_languages' => [{ 'iso_639_1' => 'fr' }] }
    @rows = [@data.dup]
    @links = Links.new([123])
    test = self
    @client = Object.new
    @requests = []
    @client.define_singleton_method(:get) do |path|
      test.instance_variable_get(:@requests) << path
      test.instance_variable_get(:@data)
    end
    @client.define_singleton_method(:search) do |**arguments|
      test.instance_variable_get(:@requests) << arguments
      { 'results' => test.instance_variable_get(:@rows) }
    end
    @resolver = EncoderProjects::SeriesOriginalLanguage.new(client: @client, links: @links)
  end

  test 'an episode references its series rather than its own title and year' do
    reference = EncoderProjects::SeriesOriginalLanguage.reference(@episode)
    assert_same @series, reference
    result = @resolver.call(reference)
    assert_equal 'french', result['status']
    assert_equal 'fr', result['language']
    assert_equal 'series', result['scope']
    assert_equal 'https://www.themoviedb.org/tv/123', result['url']
    assert_equal ['tv/123'], @requests
  end

  test 'a known series id avoids a new title search' do
    @resolver.call(@series)
    assert_equal ['tv/123'], @requests
  end

  test 'without a stored link a unique matching TV series is accepted' do
    @links.ids = []
    assert_equal 'french', @resolver.call(@series)['status']
    assert_equal [{ title: 'Joséphine, ange gardien' }, 'tv/123'], @requests
  end

  test 'a homonymous series is ambiguous rather than guessed' do
    @links.ids = []
    @rows << @data.merge('id' => 456)
    assert_equal 'unknown', @resolver.call(@series)['status']
    assert_equal 1, @requests.size
  end

  test 'conflicting stored series identities are not guessed' do
    @links.ids = [123, 456]
    assert_equal 'unknown', @resolver.call(@series)['status']
    assert_empty @requests
  end

  test 'a foreign original series remains foreign' do
    @data.merge!('original_language' => 'en', 'languages' => ['en'],
                 'spoken_languages' => [{ 'iso_639_1' => 'en' }])
    assert_equal 'foreign', @resolver.call(@series)['status']
  end

  test 'multilingual series still require confirmation' do
    @data['languages'] << 'en'
    assert_equal 'unknown', @resolver.call(@series)['status']
  end

  test 'a stale link returning another title is rejected' do
    @data.merge!('name' => 'Une autre série', 'original_name' => 'Another show')
    assert_equal 'unknown', @resolver.call(@series)['status']
  end

  test 'a different TV identity is rejected even with the same name' do
    @data['id'] = 456
    assert_equal 'unknown', @resolver.call(@series)['status']
  end

  test 'the series year is checked rather than the episode year' do
    @data['first_air_date'] = '2006-01-01'
    assert_equal 'unknown', @resolver.call(@series)['status']
  end

  test 'missing episode placement does not trigger a film search' do
    @episode.parent = nil
    assert_nil EncoderProjects::SeriesOriginalLanguage.reference(@episode)
    assert_equal 'unknown', EncoderProjects::OriginalLanguage.call(@episode)['status']
  end

  test 'other episodes resolve to the same series reference' do
    other = Node.new(id: 4, record_kind: 'episode', french_title: 'Autre titre', year: 2007, parent: @season)
    assert_same EncoderProjects::SeriesOriginalLanguage.reference(@episode),
                EncoderProjects::SeriesOriginalLanguage.reference(other)
  end

  test 'series and season records also resolve to the same reference' do
    assert_same @series, EncoderProjects::SeriesOriginalLanguage.reference(@series)
    assert_same @series, EncoderProjects::SeriesOriginalLanguage.reference(@season)
  end

  test 'the main resolver delegates series to the TV resolver' do
    result = { 'status' => 'french', 'language' => 'fr', 'provider' => 'tmdb' }
    fake = Object.new
    fake.define_singleton_method(:call) { |record| raise 'Wrong series' unless record.id == 1; result }
    EncoderProjects::SeriesOriginalLanguage.stub(:new, -> { fake }) do
      assert_equal result, EncoderProjects::OriginalLanguage.new(client: @client).call(@series)
    end
  end

  test 'network failure remains uncertainty and not a false French decision' do
    @client.define_singleton_method(:get) { |_path| raise IOError, 'offline' }
    assert_equal 'unknown', @resolver.call(@series)['status']
  end

  test 'a second episode reuses the same cached original-language result' do
    other = Node.new(id: 4, record_kind: 'episode', year: 2007, parent: @season)
    store = ActiveSupport::Cache::MemoryStore.new
    calls = []
    fake = Object.new
    result = { 'status' => 'french', 'language' => 'fr', 'provider' => 'tmdb' }
    fake.define_singleton_method(:call) { |record| calls << record.id; result }
    Rails.stub(:cache, store) do
      EncoderProjects::OriginalLanguage.stub(:new, -> { fake }) do
        assert_equal result, EncoderProjects::OriginalLanguage.call(@episode)
        assert_equal result, EncoderProjects::OriginalLanguage.call(other)
      end
    end
    assert_equal [@series.id], calls
  end
end
