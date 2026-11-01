require 'test_helper'

class EncoderProjects::FilmProposalGroupingTest < ActiveSupport::TestCase
  def wiki(**changes)
    { 'french_title' => 'La Maison du docteur Edwardes', 'original_title' => 'Spellbound', 'year' => 1945,
      'abstract' => 'Synopsis choisi.', 'source' => { 'provider' => 'wikipedia',
        'url' => 'https://fr.wikipedia.org/wiki/La_Maison_du_docteur_Edwardes' } }.merge(changes.stringify_keys)
  end

  def movie(id = 7, **changes)
    wiki.merge('source' => { 'provider' => 'tmdb', 'tmdb_movie_id' => id,
                            'url' => "https://www.themoviedb.org/movie/#{id}" },
               'poster_path' => '/poster.jpg').merge(changes.stringify_keys)
  end

  test 'one concordant film keeps Wikipedia identity and both source links with the TMDB poster' do
    original = wiki
    result = EncoderProjects::FilmProposalGrouping.call([original, movie]).sole
    assert_equal 'wikipedia', result.dig('source', 'provider')
    assert_equal 'Synopsis choisi.', result['abstract']
    assert_equal [movie['source']], result['additional_sources']
    assert_equal '/poster.jpg', result['poster_path']
    assert_nil original['poster_path']
  end

  test 'a repeated TMDB identity is displayed only once even with a different URL slug' do
    first = movie
    second = movie(source: { 'provider' => 'tmdb', 'url' => 'https://themoviedb.org/movie/7-spellbound' })
    assert_equal [first], EncoderProjects::FilmProposalGrouping.call([first, second])
  end

  test 'distinct TMDB IDs are preserved and prevent automatic grouping with Wikipedia' do
    proposals = [wiki, movie(7), movie(8)]
    assert_equal proposals, EncoderProjects::FilmProposalGrouping.call(proposals)
  end

  test 'homonyms remakes and unknown years remain separate' do
    [movie(year: 2025), movie(year: nil), movie(original_title: 'Another film'), movie(original_title: '')].each do |other|
      assert_equal 2, EncoderProjects::FilmProposalGrouping.call([wiki, other]).size
    end
  end

  test 'a missing original title cannot establish a shared identity' do
    assert_equal 2, EncoderProjects::FilmProposalGrouping.call([wiki(original_title: ''), movie]).size
  end

  test 'multiple Wikipedia identities matching one TMDB result remain available for review' do
    other = wiki(source: { 'provider' => 'wikipedia', 'url' => 'https://fr.wikipedia.org/wiki/Autre_fiche' })
    assert_equal 3, EncoderProjects::FilmProposalGrouping.call([wiki, other, movie]).size
  end

  test 'a shared title alone never hides a distinct film' do
    assert_equal 2, EncoderProjects::FilmProposalGrouping.call([wiki, movie(original_title: 'Different original')]).size
  end

  test 'TMDB first or Wikipedia first produces one card without discarding editorial values' do
    assert_equal 1, EncoderProjects::FilmProposalGrouping.call([movie, wiki]).size
    assert_equal 'Synopsis choisi.', EncoderProjects::FilmProposalGrouping.call([movie, wiki]).sole['abstract']
  end
end
