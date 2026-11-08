require 'test_helper'

class EncoderProjects::LocalEpisodePartitionsTest < ActiveSupport::TestCase
  setup do
    language = LanguageVersion.find_or_create_by!(short_name: 'IND') { |item| item.long_name = 'Indéterminée' }
    @root = Record.create!(french_title: 'Friends', record_kind: 'series', language_version: language)
    @season = @root.children.create!(french_title: 'Saison 05', rank: 5, record_kind: 'season',
                                     language_version: language)
    @parts = (1..2).map do |part|
      @season.children.create!(french_title: "Celui qui était à Las Vegas - #{part}re partie",
                                record_kind: 'episode', rank: 22 + part, language_version: language,
                                length_in_mn: 23, is_seen: part == 1, is_available: part == 1,
                                abstract: "Résumé local #{part}.")
    end
    @row = { 'tmdb_episode_id' => 86620, 'season_number' => 5, 'episode_number' => 23,
             'title_fr' => 'Celui qui était à Las Vegas', 'title_original' => 'The One in Vegas',
             'overview_fr' => 'Résumé de l’ensemble.', 'first_air_date' => '1999-05-20',
             'reference_runtime_minutes' => 46 }
    @snapshot = { 'tmdb_series_id' => 1668, 'source_url' => 'https://www.themoviedb.org/tv/1668',
                  'series' => { 'seasons' => [{ 'season_number' => 5 }] }, 'episodes' => [@row] }
  end

  def complete
    EncoderProjects::SeriesCatalogueCompletion.new(root: @root, snapshot: @snapshot).call
  end

  test 'completes the catalogue with two local parts of one external episode and preserves their data' do
    before = @parts.map { |record| record.attributes.except('updated_at', 'year', 'year_basis', 'year_evidence', 'year_history') }
    assert_no_difference(['Record.count', 'CatalogueEpisodeLink.count', 'VideoAsset.count']) do
      assert_difference('CatalogueEpisodePartition.count', 2) { complete }
    end
    @parts.each_with_index do |record, index|
      assert_equal before[index], record.reload.attributes.except('updated_at', 'year', 'year_basis', 'year_evidence', 'year_history')
      link = CatalogueEpisodePartition.find_by!(record: record)
      assert_equal 86620, link.external_episode_id
      assert_equal index + 1, link.part_number
      assert_equal 2, link.part_count
      assert_equal 46, link.evidence.fetch('whole_runtime_minutes')
      assert_equal 1999, record.year
      assert_equal 'first_release', record.year_basis
      assert_equal 1, record.year_history.size
      assert_equal(
        { 'year' => nil, 'basis' => 'unknown', 'evidence' => {} },
        record.year_history.last.slice('year', 'basis', 'evidence')
      )
    end
    assert_no_difference(['Record.count', 'CatalogueEpisodePartition.count']) { complete }
  end

  test 'a single external episode duration cannot represent two local parts' do
    @row['reference_runtime_minutes'] = 23
    assert_no_difference('CatalogueEpisodePartition.count') { assert_raises(ArgumentError) { complete } }
  end

  test 'a missing second local part is rejected' do
    @parts.last.destroy!
    assert_no_difference('CatalogueEpisodePartition.count') { assert_raises(ArgumentError) { complete } }
  end

  test 'a different base title is not associated' do
    @parts.first.update!(french_title: 'Une autre œuvre - 1re partie')
    assert_no_difference('CatalogueEpisodePartition.count') { assert_raises(ArgumentError) { complete } }
  end

  test 'a whole episode link blocks partitioning and all metadata changes roll back' do
    CatalogueEpisodeLink.create!(record: @parts.first, provider: 'tmdb', external_series_id: 1668,
                                 external_episode_id: 86620, local_season_number: 5, local_episode_number: 23,
                                 external_season_number: 5, external_episode_number: 23)
    assert_no_difference('CatalogueEpisodePartition.count') { assert_raises(ArgumentError) { complete } }
    assert_nil @parts.first.reload.year
  end

  test 'a whole episode link cannot replace an established partition' do
    complete
    link = CatalogueEpisodeLink.new(record: @parts.first, provider: 'tmdb', external_series_id: 1668,
                                    external_episode_id: 86620, local_season_number: 5, local_episode_number: 23,
                                    external_season_number: 5, external_episode_number: 23)
    assert_not link.valid?
  end

  test 'later local episodes keep their external episode number after a split' do
    following = @row.merge('episode_number' => 24, 'tmdb_episode_id' => 86621,
                           'title_fr' => 'Épisode suivant', 'title_original' => 'Next episode')
    rows = EncoderProjects::LocalEpisodePartitions.new.call(@season, [@row, following])
    assert_equal [23, 24, 25], rows.pluck('episode_number')
    assert_equal [23, 23, 24], rows.pluck('external_episode_number')
  end
end
