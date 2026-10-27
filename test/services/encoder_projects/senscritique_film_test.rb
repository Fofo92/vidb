require 'test_helper'

class EncoderProjects::SenscritiqueFilmTest < ActiveSupport::TestCase
  URL = 'https://www.senscritique.com/film/impossible/139932052'.freeze

  test 'OpenGraph fallback identifies only films and leaves unsupported fields empty' do
    html = '<meta property="og:title" content="Impossible - Téléfilm (2026) - SensCritique">'
    film = EncoderProjects::SenscritiqueFilm.new.call(html, url: URL)
    assert_equal ['Impossible', 2026, '', '', ''],
                 film.values_at('french_title', 'year', 'genres_text', 'countries_text', 'abstract')
    assert_match 'champs manquants', film['abstract_notice']
    html = '<meta property="og:title" content="Impossible - Série (2026) - SensCritique">'
    assert_nil EncoderProjects::SenscritiqueFilm.new.call(html, url: URL)
  end

  test 'malformed structured block does not hide a later valid movie' do
    html = '<script type="application/ld+json">{bad</script>' \
           '<script type="application/ld+json">{"@type":"Movie","name":"Un film"}</script>'
    film = EncoderProjects::SenscritiqueFilm.new.call(html, url: URL)
    assert_equal 'Un film', film['french_title']
    assert_nil film['year']
    assert_empty film['genres_text']
  end

  test 'ratings review text and video duration never become production metadata' do
    html = '<script type="application/ld+json">{"@type":"Review","name":"Faux film",' \
           '"reviewBody":"Une critique", "datePublished":"2026-10-16"}</script>'
    assert_nil EncoderProjects::SenscritiqueFilm.new.call(html, url: URL)
  end
end
