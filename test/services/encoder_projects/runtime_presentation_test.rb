require 'test_helper'

class EncoderProjects::RuntimePresentationTest < ActiveSupport::TestCase
  PresentationRecord = Struct.new(:length_in_mn) do
    def attributes
      { 'french_title' => 'Film', 'record_kind' => 'standalone_video' }
    end

    def language_version
      Struct.new(:short_name).new('IND')
    end

    def effective_genders
      []
    end

    def effective_countries
      []
    end

    def record_kind_episode?
      false
    end
  end

  test 'the encoder response includes the existing catalogue duration without a network request' do
    assert_equal 40, EncoderProjects::RecordPresentation.call(PresentationRecord.new(40))['reference_runtime_minutes']
    assert_nil EncoderProjects::RecordPresentation.call(PresentationRecord.new(nil))['reference_runtime_minutes']
  end

  test 'Wikipedia film runtime is extracted without altering its synopsis or year' do
    html = <<~HTML
      <div class="infobox"><table>
      <tr><th>Réalisation</th><td>Une réalisatrice</td></tr>
      <tr><th>Genre</th><td>Drame</td></tr>
      <tr><th>Sortie</th><td>2026</td></tr>
      <tr><th>Durée</th><td>1 h 40 min</td></tr></table></div>
      <p>Un film de test.</p><h2 id="Synopsis">Synopsis</h2><p>Un résumé.</p>
    HTML
    proposal = EncoderProjects::WikipediaFilm.new.call('title' => 'Film test', 'pageid' => 1, 'text' => { '*' => html })
    assert_equal 100, proposal['reference_runtime_minutes']
    assert_equal 2026, proposal['year']
    assert_equal 'Un résumé.', proposal['abstract']
  end

  test 'SensCritique film runtime is extracted from the structured duration only' do
    html = '<script type="application/ld+json">{"@type":"Movie","name":"Film test","duration":"PT1H40M"}</script>'
    proposal = EncoderProjects::SenscritiqueFilm.new.call(html, url: 'https://www.senscritique.com/film/test/123')
    assert_equal 100, proposal['reference_runtime_minutes']
  end
end
