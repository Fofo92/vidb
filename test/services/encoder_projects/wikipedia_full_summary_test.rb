require 'test_helper'

class EncoderProjects::WikipediaFullSummaryTest < ActiveSupport::TestCase
  test 'episode extraction preserves the complete narrative for the synopsis policy to classify' do
    text = ('Une aventure commence. ' * 100).strip
    page = { 'title' => 'Saison 2 de Série test', 'text' => { '*' =>
      "<h3>Épisode 1 : Le départ</h3><div>Résumé détaillé</div><p>#{text}</p>" } }
    result = EncoderProjects::WikipediaEpisode.new.call(page, 1)
    assert_equal text, result['abstract']
  end

  test 'film extraction does not cut a synopsis in the middle of a sentence' do
    text = ('Une aventure commence. ' * 250).strip
    html = <<~HTML
      <div class="infobox"><table>
      <tr><th>Réalisation</th><td>Une réalisatrice</td></tr>
      <tr><th>Genre</th><td>Drame</td></tr>
      <tr><th>Sortie</th><td>2025</td></tr></table></div>
      <p>Un film de test.</p><h2 id="Synopsis">Synopsis</h2><p>#{text}</p><h2>Distribution</h2>
    HTML
    result = EncoderProjects::WikipediaFilm.new.call('title' => 'Film test', 'pageid' => 1, 'text' => { '*' => html })
    assert_equal text, result['abstract']
  end
end
