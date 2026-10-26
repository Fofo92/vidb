require 'test_helper'

class EncoderProjects::WikipediaEditionSnapshotTest < ActiveSupport::TestCase
  def snapshot
    names = ['Madeleine', 'Madeleine (2)', 'Nikki & Evelina', 'Nikki & Evelina (2)', 'Birgitta', 'Birgitta (2)']
    { 'tmdb_series_id' => 987, 'source_url' => 'https://www.themoviedb.org/tv/987',
      'series' => { 'seasons' => [{ 'season_number' => 10 }] },
      'episodes' => names.each_with_index.map do |name, index|
        { 'tmdb_episode_id' => 100 + index, 'season_number' => 10, 'episode_number' => index + 1,
          'title_fr' => name, 'title_original' => name, 'first_air_date' => '2024-08-14',
          'reference_runtime_minutes' => 44 }
      end }
  end

  def candidate
    { 'season' => 10, 'episode' => 2, 'source' => { 'numbering_basis' => 'season_ordered_list', 'page_title' => 'Série test' },
      'external_parts' => [{ 'episode_id' => 102 }, { 'episode_id' => 103 }] }
  end

  def service
    wiki = Object.new
    wiki.define_singleton_method(:page) do |_title|
      { 'title' => 'Série test', 'text' => { '*' => '<h3>Saison 10 (2024)</h3>' \
        '<ol><li>Madeleine</li><li>Nikki et Evelina</li><li>Birgitta</li></ol>' } }
    end
    EncoderProjects::WikipediaEditionSnapshot.new(wikipedia: wiki)
  end

  test 'adapts the snapshot before any database write and verifies the selected parts' do
    data = snapshot
    result = service.call(data, candidate)
    assert_equal 3, result['episodes'].size
    assert_equal [102, 103], result['episodes'][1]['external_parts'].pluck('episode_id')
    assert_equal 6, data['episodes'].size
    changed = candidate.merge('external_parts' => [{ 'episode_id' => 103 }, { 'episode_id' => 104 }])
    assert_raises(ArgumentError) { service.call(data, changed) }
  end

  test 'no convention leaves the existing catalogue representation unchanged' do
    data = snapshot
    assert_same data, service.call(data, { 'source' => { 'provider' => 'tmdb' } })
  end
end
