require 'test_helper'

class EncoderProjects::WikipediaEpisodeTest < ActiveSupport::TestCase
  def page(html)
    { 'title' => 'Saison 2 de Série Exemple', 'text' => { '*' => html } }
  end

  test 'extracts only the requested episode and its earliest broadcast year' do
    result = EncoderProjects::WikipediaEpisode.new.call(page(<<~HTML), 1)
      <h3>Épisode 1 : Le départ</h3>
      <dl><dt>Première diffusion</dt><dd>Belgique : 2024 ; France : 2025</dd>
      <dt>Résumé détaillé</dt><dd>Une aventure commence.</dd></dl>
      <h3>Épisode 2 : Le retour</h3><dl><dt>Première diffusion</dt><dd>2026</dd></dl>
    HTML
    assert_equal 'Le départ', result['title']
    assert_equal 2024, result['year']
    assert_equal 'Une aventure commence.', result['abstract']
    assert_equal 'wikipedia', result.dig('source', 'provider')
  end

  test 'supports modern wrapped headings and does not invent an unknown date' do
    result = EncoderProjects::WikipediaEpisode.new.call(page(<<~HTML), 1)
      <div class="mw-heading mw-heading3"><h3>Épisode 1 : Le départ</h3><span class="mw-editsection">modifier</span></div>
      <dl><dt>Audiences</dt><dd>1999 personnes</dd></dl>
      <div class="mw-heading mw-heading3"><h3>Épisode 2 : Le retour</h3></div>
      <dl><dt>Première diffusion</dt><dd>2025</dd></dl>
    HTML
    assert_equal 'Le départ', result['title']
    assert_nil result['year']
    assert_equal '', result['abstract']
  end

  test 'does not reuse a different episode or the season global date' do
    html = '<table><tr><th>Première diffusion</th><td>2025</td></tr></table><h3>Épisode 2 : Suite</h3>'
    assert_nil EncoderProjects::WikipediaEpisode.new.call(page(html), 1)
  end

  test 'extracts production countries and genres from the series infobox' do
    html = '<table><tr><th>Genre</th><td>Drame</td></tr><tr><th>Pays d’origine</th><td>France</td></tr></table>'
    result = EncoderProjects::WikipediaEpisode.new.references(page(html))
    assert_equal 'Drame', result['genres_text']
    assert_equal 'France', result['countries_text']
  end
end
