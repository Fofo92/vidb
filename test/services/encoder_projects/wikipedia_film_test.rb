require 'test_helper'

class EncoderProjects::WikipediaFilmTest < ActiveSupport::TestCase
  def page(extra = '')
    { 'title' => 'Adieu Philippine', 'pageid' => 123,
      'text' => { '*' => <<~HTML } }
        <table class="infobox"><tr><th>Réalisation</th><td>Jacques Rozier</td></tr>
        <tr><th>Pays de production</th><td>France</td></tr>
        <tr><th>Genre</th><td>Comédie dramatique</td></tr>
        <tr><th>Sortie</th><td>1962</td></tr></table>
        <p>Adieu Philippine est un film français.</p>
        <h2><span id="Synopsis">Synopsis</span></h2><p>Résumé de test du film.</p>
        <h2>Distribution</h2><p>Ne pas importer cette distribution.</p>#{extra}
      HTML
  end

  test 'extracts the film year genres country synopsis and source without a network call' do
    result = EncoderProjects::WikipediaFilm.new.call(page)
    assert_equal 'Adieu Philippine', result['french_title']
    assert_equal 1962, result['year']
    assert_equal 'Comédie dramatique', result['genres_text']
    assert_equal 'France', result['countries_text']
    assert_equal 'Résumé de test du film.', result['abstract']
    assert_equal 'wikipedia', result.dig('source', 'provider')
    assert_equal 'https://fr.wikipedia.org/wiki/Adieu_Philippine', result.dig('source', 'url')
  end

  test 'supports the new heading wrapper and does not import the next section' do
    value = page
    value['text']['*'].sub!('<h2><span id="Synopsis">Synopsis</span></h2>',
                           '<div class="mw-heading"><h2 id="Synopsis">Synopsis</h2></div>')
    assert_equal 'Résumé de test du film.', EncoderProjects::WikipediaFilm.new.call(value)['abstract']
  end

  test 'supports a table without a class inside a modern infobox container and initial blank paragraphs' do
    value = page
    value['text']['*'].sub!('<table class="infobox">', '<p></p><p></p><div class="infobox_v3"><table>')
    value['text']['*'].sub!('</table>', '</table></div>')
    assert_equal 1962, EncoderProjects::WikipediaFilm.new.call(value)['year']
  end

  test 'a disambiguation page is not silently turned into a film' do
    value = { 'title' => 'Homonymie', 'pageid' => 1, 'text' => { '*' => '<p>Plusieurs œuvres.</p>' } }
    assert_nil EncoderProjects::WikipediaFilm.new.call(value)
  end
end
