require 'test_helper'

class EncoderOriginalLanguageTest < ActiveSupport::TestCase
  Film = Struct.new(:id, :record_kind, :french_title, :original_title, :year)

  setup do
    @film = Film.new(42, 'standalone_video', 'Il ne faut jurer de rien', 'Il ne faut jurer de rien', 2005)
    @movie = { 'id' => 123, 'title' => @film.french_title, 'original_title' => @film.original_title,
               'release_date' => '2005-09-28', 'original_language' => 'fr',
               'spoken_languages' => [{ 'iso_639_1' => 'fr' }] }
    @rows = [@movie.dup]
    test = self
    @client = Object.new
    @client.define_singleton_method(:search) { |**_arguments| { 'results' => test.instance_variable_get(:@rows) } }
    @client.define_singleton_method(:movie) { |**_arguments| test.instance_variable_get(:@movie) }
    @resolver = EncoderProjects::OriginalLanguage.new(client: @client)
  end

  test 'a unique film with matching title and year provides French evidence and its source' do
    result = @resolver.call(@film)
    assert_equal 'french', result['status']
    assert_equal 'fr', result['language']
    assert_equal 'https://www.themoviedb.org/movie/123', result['url']
  end

  test 'a foreign original provides foreign evidence' do
    @movie['original_language'] = 'en'
    @movie['spoken_languages'] = [{ 'iso_639_1' => 'en' }]
    assert_equal 'foreign', @resolver.call(@film)['status']
  end

  test 'multiple matching films require user confirmation' do
    @rows << @movie.merge('id' => 456)
    assert_equal 'unknown', @resolver.call(@film)['status']
  end

  test 'a similarly named film from another year is rejected' do
    @rows.first['release_date'] = '2015-09-28'
    assert_equal 'unknown', @resolver.call(@film)['status']
  end

  test 'a different title is rejected even with the same year' do
    @rows.first.merge!('title' => 'Autre film', 'original_title' => 'Other movie')
    assert_equal 'unknown', @resolver.call(@film)['status']
  end

  test 'detail identity is checked again before accepting language' do
    @movie['release_date'] = '2010-01-01'
    assert_equal 'unknown', @resolver.call(@film)['status']
  end

  test 'multilingual films require user confirmation' do
    @movie['spoken_languages'] << { 'iso_639_1' => 'en' }
    assert_equal 'unknown', @resolver.call(@film)['status']
  end

  test 'absent or undefined original language requires user confirmation' do
    [nil, '', 'xx', 'qaa'].each do |language|
      @movie['original_language'] = language
      assert_equal 'unknown', @resolver.call(@film)['status']
    end
  end

  test 'network failure returns uncertainty instead of breaking identification' do
    @client.define_singleton_method(:search) { |**_arguments| raise IOError, 'offline' }
    assert_equal 'unknown', @resolver.call(@film)['status']
  end

  test 'an episode never triggers a film lookup' do
    @film.record_kind = 'episode'
    assert_equal 'unknown', EncoderProjects::OriginalLanguage.call(@film)['status']
  end

  test 'missing year never triggers a film lookup' do
    @film.year = nil
    assert_equal 'unknown', EncoderProjects::OriginalLanguage.call(@film)['status']
  end
end
