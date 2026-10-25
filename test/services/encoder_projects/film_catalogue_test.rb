require 'test_helper'
require 'minitest/mock'

class EncoderProjects::FilmCatalogueTest < ActiveSupport::TestCase
  test 'wikipedia candidates have priority and do not trigger a TMDB search' do
    wiki = Object.new
    wiki.define_singleton_method(:search) { |_title| ['Film'] }
    wiki.define_singleton_method(:page) { |_title| { 'page' => 'Film' } }
    parser = Object.new
    parser.define_singleton_method(:call) do |_page|
      { 'french_title' => 'Film', 'source' => { 'url' => 'https://fr.wikipedia.org/wiki/Film' } }
    end
    tmdb = Object.new
    tmdb.define_singleton_method(:search) { |**_arguments| raise 'TMDB ne doit pas être appelé' }
    result = EncoderProjects::FilmCatalogue.new(wikipedia: wiki, parser: parser, tmdb: tmdb).call('Film')
    assert_equal 'Film', result.sole['french_title']
  end

  test 'a direct wikipedia URL is read as a page without searching the whole URL' do
    wiki = Object.new
    wiki.define_singleton_method(:search) { |_title| raise 'Recherche indue' }
    wiki.define_singleton_method(:page) { |title| { 'title' => title } }
    parser = Object.new
    parser.define_singleton_method(:call) do |page|
      { 'french_title' => page['title'], 'source' => { 'url' => 'https://fr.wikipedia.org/wiki/Film' } }
    end
    result = EncoderProjects::FilmCatalogue.new(wikipedia: wiki, parser: parser).call('https://fr.wikipedia.org/wiki/Film')
    assert_equal 'Film', result.sole['french_title']
  end

  test 'invalid titles are refused before network access' do
    assert_raises(ArgumentError) { EncoderProjects::FilmCatalogue.new.call('') }
    assert_raises(ArgumentError) { EncoderProjects::FilmCatalogue.new.call('a' * 301) }
  end
end
