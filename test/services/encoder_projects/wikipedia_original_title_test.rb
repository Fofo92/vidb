require 'test_helper'

class EncoderProjects::WikipediaOriginalTitleTest < ActiveSupport::TestCase
  test 'extracts the original title without merging it into the French title' do
    html = '<h3>Épisode 12 : Boston</h3><dl><dt>Titre original</dt><dd><i>Boston</i></dd>' \
           '<dt>Première diffusion</dt><dd>2022</dd><dt>Résumé</dt><dd>Un bref résumé.</dd></dl>'
    proposal = EncoderProjects::WikipediaEpisode.new.call({ 'title' => 'Saison 5', 'text' => { '*' => html } }, 12)
    assert_equal 'Boston', proposal['title']
    assert_equal 'Boston', proposal['original_title']
    assert_equal 2022, proposal['year']
  end

  test 'existing original titles take precedence over a new source proposal' do
    record = Struct.new(:french_title, :original_title, :year, :id, :language_version)
                   .new('Le départ', 'Manual title', 2025, 12, Struct.new(:short_name).new('VF'))
    values = EncoderProjects::EpisodeDefaults.editorial(record, Struct.new(:title).new('Source title'),
                                                       { 'title' => 'Le départ', 'original_title' => 'Departure' })
    assert_equal 'Manual title', values['original_title']
    assert_equal 'Manual title', values['previous_original_title']
  end
end
