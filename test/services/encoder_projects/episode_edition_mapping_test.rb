require 'test_helper'

class EncoderProjects::EpisodeEditionMappingTest < ActiveSupport::TestCase
  def rows
    titles = ['Madeleine', 'Madeleine (2)', 'Nikki & Evelina', 'Nikki & Evelina (2)', 'Birgitta', 'Birgitta (2)']
    titles.each_with_index.map do |title, index|
      { 'tmdb_episode_id' => 100 + index, 'season_number' => 10, 'episode_number' => index + 1,
        'title_fr' => title, 'title_original' => title, 'overview_fr' => 'Bref synopsis.',
        'first_air_date' => '2024-08-14', 'reference_runtime_minutes' => index.odd? ? 43 : 44 }
    end
  end

  def local
    ['Madeleine', 'Nikki et Evelina', 'Birgitta'].each_with_index.to_h do |title, index|
      [index + 1, { 'title' => title, 'source' => { 'numbering_basis' => 'season_ordered_list',
                                                  'page_title' => 'Meurtres à Sandhamn' } }]
    end
  end

  test 'groups all explicitly identified parts while keeping the local numbering' do
    original = rows
    result = EncoderProjects::EpisodeEditionMapping.new.call(original, local)
    assert_equal [1, 2, 3], result.pluck('episode_number')
    assert_equal ['Madeleine', 'Nikki et Evelina', 'Birgitta'], result.pluck('title_fr')
    assert_equal [[1, 2], [3, 4], [5, 6]], result.map { |row| row.fetch('external_parts').pluck('episode_number') }
    assert_equal [87, 87, 87], result.pluck('reference_runtime_minutes')
    assert_equal [1, 3, 5], result.pluck('external_episode_number')
    assert_equal 'Nikki & Evelina', result[1]['title_original']
    assert_equal (1..6).to_a, original.pluck('episode_number')
  end

  test 'does not merge unrelated episodes just because their numbers are consecutive' do
    changed = rows
    changed[3]['title_fr'] = changed[3]['title_original'] = 'Une autre œuvre (2)'
    assert_raises(ArgumentError) { EncoderProjects::EpisodeEditionMapping.new.call(changed, local) }
  end

  test 'missing duplicated and non consecutive parts are rejected' do
    parser = EncoderProjects::EpisodeEditionMapping.new
    assert_raises(ArgumentError) { parser.call(rows.reject { |row| row['episode_number'] == 4 }, local) }
    assert_raises(ArgumentError) { parser.call(rows + [rows[3].dup], local) }
    changed = rows
    changed[3]['episode_number'] = 40
    assert_raises(ArgumentError) { parser.call(changed, local) }
  end

  test 'unknown durations stay unknown and are never treated as measured durations' do
    changed = rows
    changed[3]['reference_runtime_minutes'] = nil
    result = EncoderProjects::EpisodeEditionMapping.new.call(changed, local)
    assert_nil result[1]['reference_runtime_minutes']
    assert_equal 2, result[1]['external_parts'].size
  end

  test 'explicit local parts can remain separate and no source list means no inferred grouping' do
    entries = rows.each_with_object({}) do |row, result|
      title = row['title_fr']
      title += ' (1)' if row['episode_number'].odd?
      result[row['episode_number']] = { 'title' => title, 'source' => {} }
    end
    result = EncoderProjects::EpisodeEditionMapping.new.call(rows, entries)
    assert_equal 6, result.size
    assert result.all? { |row| row['external_parts'].one? }
    untouched = rows
    assert_same untouched, EncoderProjects::EpisodeEditionMapping.new.call(untouched, {})
  end
end
