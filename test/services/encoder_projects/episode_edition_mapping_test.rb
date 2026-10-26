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

  def map_titles(french, native, titles)
    source = french.each_with_index.map do |title, index|
      { 'tmdb_episode_id' => 100 + index, 'episode_number' => index + 1,
        'title_fr' => title, 'title_original' => native[index], 'reference_runtime_minutes' => 44 }
    end
    entries = titles.each_with_index.to_h { |title, index| [index + 1, { 'title' => title, 'source' => {} }] }
    EncoderProjects::EpisodeEditionMapping.new.call(source, entries)
  end

  test 'season six accepts parenthesized part labels and original titles inside local titles' do
    french = ["Le prix à payer (A l'ombre du pouvoir) part 1", "Le prix à payer (A l'ombre du pouvoir) part 2",
              'Au nom de la vérité (part1)', 'Au nom de la vérité (part 2)',
              'À la vie, à la mort (part 1)', 'À la vie, à la mort (part 2)',
              'Un goût amer (part 1)', 'Un goût amer (part 2)']
    native = ['I maktens skugga', 'I sanningens namn', 'I fel sällskap', 'I nöd och lust']
             .flat_map { |title| ["#{title} (1)", "#{title} (2)"] }
    titles = ['Le Prix à payer (I maktens skugga)', 'Au nom de la vérité (I sanningens namn)',
              'À la vie, à la mort (I fel sällskap)', 'Un goût amer (I nöd och lust)']
    result = map_titles(french, native, titles)
    assert_equal [[1, 2], [3, 4], [5, 6], [7, 8]], result.map { |row| row['external_parts'].pluck('episode_number') }
    assert_equal titles, result.pluck('title_fr')
    assert_equal 'Au nom de la vérité', EncoderProjects::EpisodeEditionTitles.base(french[2])
    assert_equal 1, EncoderProjects::EpisodeEditionTitles.part(french[2])
  end

  test 'season eight uses consistent original markers and retains divergent translated labels' do
    french = ['Angelica (1)', 'Angelica (2)', 'Lili (1)', 'Lili (2)', 'Olivia (1)', 'Olivia (3)']
    native = french.dup
    native[5] = 'Olivia (2)'
    result = map_titles(french, native, ['Angelica', 'Lili', 'Olivia'])
    assert_equal [5, 6], result.last['external_parts'].pluck('episode_number')
    assert_equal 'Olivia (3)', result.last['external_parts'].last['title']
    assert_equal 'Olivia (2)', result.last['external_parts'].last['original_title']
  end

  test 'season eleven groups original titles despite generic translated second parts' do
    french = ['Linnéa', 'Épisode 2', 'Rakel', 'Épisode 4', 'Amanda', 'Épisode 6']
    native = ['Linnéa', 'Rakel', 'Amanda'].flat_map { |title| ["#{title} (1)", "#{title} (2)"] }
    result = map_titles(french, native, ['Linnéa', 'Rakel', 'Amanda'])
    assert_equal ['Linnéa', 'Rakel', 'Amanda'], result.pluck('title_fr')
    assert_equal [[1, 2], [3, 4], [5, 6]], result.map { |row| row['external_parts'].pluck('episode_number') }
  end

  test 'inconsistent original parts still refuse grouping even with plausible translated titles' do
    assert_raises(ArgumentError) do
      map_titles(['Olivia (1)', 'Olivia (2)'], ['Olivia (1)', 'Olivia (3)'], ['Olivia'])
    end
  end

  test 'translated part labels remain usable when original titles are absent' do
    result = map_titles(['Enquête (part1)', 'Enquête (part 2)'], [nil, nil], ['Enquête'])
    assert_equal [1, 2], result.sole['external_parts'].pluck('episode_number')
  end
end
