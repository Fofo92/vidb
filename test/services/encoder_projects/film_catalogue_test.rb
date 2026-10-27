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
    catalogue = EncoderProjects::FilmCatalogue.new(wikipedia: wiki, parser: parser, tmdb: empty_tmdb, senscritique: empty_senscritique)
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

  test 'a direct SensCritique link bypasses Wikipedia and TMDB' do
    wiki = Object.new
    wiki.define_singleton_method(:search) { |_title| raise 'Recherche Wikipédia indue' }
    tmdb = Object.new
    tmdb.define_singleton_method(:search) { |title:| raise 'Recherche TMDB indue' }
    source = empty_senscritique
    source.define_singleton_method(:call) do |_query|
      [{ 'french_title' => 'Impossible', 'year' => 2026, 'abstract' => 'Synopsis.',
         'source' => { 'provider' => 'senscritique', 'url' => 'https://www.senscritique.com/film/impossible/139932052' } }]
    end
    films = EncoderProjects::FilmCatalogue.new(wikipedia: wiki, tmdb: tmdb, senscritique: source)
    assert_equal 'Impossible', films.call('https://www.senscritique.com/film/impossible/139932052').sole['french_title']
    assert_empty films.warnings
  end

  test 'SensCritique is a fallback when Wikipedia and TMDB have no film' do
    wiki = Object.new
    wiki.define_singleton_method(:search) { |_query| [] }
    source = empty_senscritique
    source.define_singleton_method(:call) do |query|
      [{ 'french_title' => query, 'year' => 2026, 'abstract' => 'Synopsis de test.',
         'source' => { 'provider' => 'senscritique', 'url' => 'https://www.senscritique.com/film/impossible/139932052' } }]
    end
    films = EncoderProjects::FilmCatalogue.new(wikipedia: wiki, tmdb: empty_tmdb, senscritique: source)
    assert_equal 'Impossible', films.call('Impossible').sole['french_title']
  end

  test 'a SensCritique warning preserves an existing Wikipedia candidate' do
    wiki = Object.new
    wiki.define_singleton_method(:search) { |_query| ['Film'] }
    wiki.define_singleton_method(:page) { |_query| {} }
    parser = Object.new
    parser.define_singleton_method(:call) do |_page|
      { 'french_title' => 'Film', 'year' => 2026, 'abstract' => 'Court résumé.',
        'source' => { 'provider' => 'wikipedia', 'url' => 'https://fr.wikipedia.org/wiki/Film' } }
    end
    source = empty_senscritique
    source.define_singleton_method(:warnings) { ['SensCritique indisponible (HTTP 403)'] }
    films = EncoderProjects::FilmCatalogue.new(wikipedia: wiki, parser: parser, tmdb: empty_tmdb, senscritique: source)
    assert_equal 'Film', films.call('Film').sole['french_title']
    assert_equal ['SensCritique indisponible (HTTP 403)'], films.warnings
  end

  def empty_senscritique
    client = Object.new
    client.define_singleton_method(:call) { |_query| [] }
    client.define_singleton_method(:warnings) { [] }
    client
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
    result = EncoderProjects::FilmCatalogue.new(wikipedia: wiki, parser: parser, tmdb: empty_tmdb, senscritique: empty_senscritique).call('https://fr.wikipedia.org/wiki/Film')
    assert_equal 'Film', result.sole['french_title']
  end

  test 'invalid titles are refused before network access' do
    assert_raises(ArgumentError) { EncoderProjects::FilmCatalogue.new.call('') }
    assert_raises(ArgumentError) { EncoderProjects::FilmCatalogue.new.call('a' * 301) }
  end
end
