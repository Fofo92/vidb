require 'test_helper'
require 'minitest/mock'

class EncoderProjects::FilmCatalogueTest < ActiveSupport::TestCase
  test 'Wikipedia identity remains first while a matching TMDB synopsis is proposed' do
    wiki = Object.new
    wiki.define_singleton_method(:search) { |_title| ['Film'] }
    wiki.define_singleton_method(:page) { |_title| { 'page' => 'Film' } }
    parser = Object.new
    parser.define_singleton_method(:call) do |_page|
      { 'french_title' => 'Film', 'year' => 2025, 'abstract' => 'Un récit très détaillé. ' * 100,
        'source' => { 'provider' => 'wikipedia', 'url' => 'https://fr.wikipedia.org/wiki/Film' } }
    end
    catalogue = EncoderProjects::FilmCatalogue.new(wikipedia: wiki, parser: parser, tmdb: empty_tmdb)
    catalogue.define_singleton_method(:tmdb_films) do |_title|
      [{ 'french_title' => 'Film', 'year' => 2025, 'abstract' => 'Synopsis court.',
         'source' => { 'provider' => 'tmdb', 'url' => 'https://www.themoviedb.org/movie/7' } }]
    end
    result = catalogue.call('Film')
    assert_equal 'Film', result.first['french_title']
    assert_equal 'wikipedia', result.first.dig('source', 'provider')
    assert_equal 'Synopsis court.', result.first['abstract']
    assert_equal 'tmdb', result.first.dig('abstract_source', 'provider')
  end

  def empty_tmdb
    client = Object.new
    client.define_singleton_method(:search) { |title:| { 'results' => [] } }
    client
  end

  test 'a direct wikipedia URL is read as a page without searching the whole URL' do
    wiki = Object.new
    wiki.define_singleton_method(:search) { |_title| raise 'Recherche indue' }
    wiki.define_singleton_method(:page) { |title| { 'title' => title } }
    parser = Object.new
    parser.define_singleton_method(:call) do |page|
      { 'french_title' => page['title'], 'source' => { 'url' => 'https://fr.wikipedia.org/wiki/Film' } }
    end
    result = EncoderProjects::FilmCatalogue.new(wikipedia: wiki, parser: parser, tmdb: empty_tmdb).call('https://fr.wikipedia.org/wiki/Film')
    assert_equal 'Film', result.sole['french_title']
  end

  test 'invalid titles are refused before network access' do
    assert_raises(ArgumentError) { EncoderProjects::FilmCatalogue.new.call('') }
    assert_raises(ArgumentError) { EncoderProjects::FilmCatalogue.new.call('a' * 301) }
  end
end
