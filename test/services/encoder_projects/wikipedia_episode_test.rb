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
  test 'reads fields outside the immediate parent of the episode heading' do
    result = EncoderProjects::WikipediaEpisode.new.call(page(<<~HTML), 1)
      <section><div><h3>Épisode 1 : Le départ</h3></div></section>
      <div><div><span>Première diffusion</span></div></div>
      <div><ul><li>Belgique : <a>2024</a></li><li>France : <a>2025</a></li></ul></div>
      <div><div><span>Résumé détaillé</span></div></div>
      <div><p>Le héros <a>retrouve</a> sa famille.</p><p>Le voyage commence.</p></div>
      <h3>Épisode 2 : Suite</h3><div>Première diffusion</div><div>2026</div>
    HTML
    assert_equal 2024, result['year']
    assert_equal 'Le héros retrouve sa famille. Le voyage commence.', result['abstract']
  end

  test 'supports field labels as subsection headings and stops at the next episode' do
    result = EncoderProjects::WikipediaEpisode.new.call(page(<<~HTML), 1)
      <h3>Épisode 1 : Le départ</h3>
      <h4>Première diffusion</h4><p>2025</p>
      <h4>Résumé détaillé</h4><p>Un voyage commence.</p>
      <h3>Épisode 2 : Suite</h3><p>Autre histoire en 1990.</p>
    HTML
    assert_equal 2025, result['year']
    assert_equal 'Un voyage commence.', result['abstract']
  end

  test 'does not mistake dates in the plot or audiences for a broadcast year' do
    result = EncoderProjects::WikipediaEpisode.new.call(page(<<~HTML), 1)
      <h3>Épisode 1 : Le départ</h3>
      <div>Audiences</div><div>1999 personnes</div>
      <div>Résumé détaillé</div><p>Une histoire située en 1985.</p>
    HTML
    assert_nil result['year']
    assert_equal 'Une histoire située en 1985.', result['abstract']
  end

  test 'supports colon separated plain text fields without semantic label tags' do
    result = EncoderProjects::WikipediaEpisode.new.call(page(<<~HTML), 1)
      <h3>Épisode 1 : Le départ</h3>
      <p>Première diffusion : 2025</p><p>Résumé : Une aventure commence.</p>
      <p>Commentaires : Information éditoriale à exclure.</p>
    HTML
    assert_equal 2025, result['year']
    assert_equal 'Une aventure commence.', result['abstract']
  end

end
