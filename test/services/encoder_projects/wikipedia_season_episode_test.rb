require 'test_helper'

class EncoderProjects::WikipediaSeasonEpisodeTest < ActiveSupport::TestCase
  def page(html)
    { 'title' => 'Meurtres à Sandhamn', 'text' => { '*' => html } }
  end

  test 'reads a season list from the series article without inventing a synopsis' do
    html = '<div class="mw-heading"><h3>Saison 9 (2023)</h3></div><ol><li>Autre enquête</li></ol>' \
           '<div class="mw-heading"><h3>Saison 10 (2024)</h3></div><p>Présentation.</p>' \
           '<ol><li>Madeleine</li><li>Nikki et Evelina</li><li>Birgitta</li></ol>' \
           '<h3>Saison 11 (2025)</h3><ol><li>Autre</li></ol>'
    result = EncoderProjects::WikipediaSeasonEpisode.new.call(page(html), 10, 2)
    assert_equal 'Nikki et Evelina', result['title']
    assert_equal 2024, result['year']
    assert_equal '', result['abstract']
    assert_equal 'season_ordered_list', result.dig('source', 'numbering_basis')
    assert_nil EncoderProjects::WikipediaSeasonEpisode.new.call(page(html), 10, 4)
  end

  test 'does not borrow a list from the following season or infer split broadcasts' do
    html = '<h3>Saison 10 (2024)</h3><p>Aucun épisode documenté.</p>' \
           '<h3>Saison 11 (2025)</h3><ol><li>Autre</li></ol>'
    assert_nil EncoderProjects::WikipediaSeasonEpisode.new.call(page(html), 10, 1)
    html = '<h3>Saison 10 (2024)</h3><ol><li>Enquête<ol><li>Partie 1</li><li>Partie 2</li></ol></li></ol>'
    assert_nil EncoderProjects::WikipediaSeasonEpisode.new.call(page(html), 10, 1)
  end

  test 'respects explicit ordered list numbering and removes global inquiry prefixes' do
    html = '<h3>Saison 6 (2018)</h3><ol start="2"><li>Enquête 7 : Le départ : Description.</li>' \
           '<li value="4">Autre enquête</li></ol>'
    parser = EncoderProjects::WikipediaSeasonEpisode.new
    assert_equal 'Le départ', parser.call(page(html), 6, 2)['title']
    assert_nil parser.call(page(html), 6, 3)
    assert_equal 'Autre enquête', parser.call(page(html), 6, 4)['title']
  end

  test 'does not turn untitled episode descriptions into episode titles' do
    html = '<h3>Saison 1 (2010)</h3><ul><li>Épisode 1/3 : Description de l’enquête.</li></ul>'
    assert_nil EncoderProjects::WikipediaSeasonEpisode.new.call(page(html), 1, 1)
  end
end
