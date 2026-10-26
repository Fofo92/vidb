require 'test_helper'

class EncoderProjects::SeriesCatalogueWholeEpisodesTest < ActiveSupport::TestCase
  setup do
    language = LanguageVersion.find_or_create_by!(short_name: 'IND') { |row| row.long_name = 'Indéterminée' }
    @root = Record.create!(french_title: 'Série des éditions', record_kind: 'series', language_version: language)
    rows = ['Madeleine', 'Madeleine (2)', 'Nikki & Evelina', 'Nikki & Evelina (2)', 'Birgitta', 'Birgitta (2)']
           .each_with_index.map do |title, index|
      { 'tmdb_episode_id' => 100 + index, 'season_number' => 10, 'episode_number' => index + 1,
        'title_fr' => title, 'title_original' => title, 'overview_fr' => 'Synopsis court.',
        'first_air_date' => '2024-08-14', 'reference_runtime_minutes' => 44 }
    end
    source = { 'provider' => 'wikipedia', 'numbering_basis' => 'season_ordered_list', 'page_title' => 'Série des éditions' }
    entries = ['Madeleine', 'Nikki et Evelina', 'Birgitta'].each_with_index.to_h do |title, index|
      [index + 1, { 'title' => title, 'source' => source }]
    end
    @snapshot = { 'tmdb_series_id' => 987, 'source_url' => 'https://www.themoviedb.org/tv/987',
                  'series' => { 'seasons' => [{ 'season_number' => 10 }] },
                  'episodes' => EncoderProjects::EpisodeEditionMapping.new.call(rows, entries) }
  end

  def complete
    EncoderProjects::SeriesCatalogueCompletion.new(root: @root, snapshot: @snapshot).call
  end

  test 'creates three complete episodes and durably records all six external references' do
    assert_difference('Record.count', 4) do
      assert_difference('CatalogueEpisodeLink.count', 3) do
        assert_no_difference('VideoAsset.count') { complete }
      end
    end
    episode = @root.descendants.find_by!(record_kind: 'episode', rank: 2)
    assert_equal 'Nikki et Evelina', episode.french_title
    assert_equal false, episode.is_recorded
    assert_equal false, episode.is_available
    assert_equal false, episode.effective_state(:is_seen)
    assert_nil episode.length_in_mn
    assert_empty episode.media
    link = CatalogueEpisodeLink.find_by!(record: episode, provider: 'tmdb')
    assert_equal 2, link.local_episode_number
    assert_equal 3, link.external_episode_number
    assert_equal [102, 103], link.evidence.fetch('external_parts').pluck('episode_id')
    assert_equal 88, link.evidence['reference_runtime_minutes']
    assert_match %r{/episode/3\z}, link.evidence['url']
    episode.update!(is_seen: true, french_title: 'Mon titre manuel', abstract: 'Ma traduction.')
    assert_no_difference(['Record.count', 'CatalogueEpisodeLink.count', 'VideoAsset.count']) { complete }
    assert_equal true, episode.reload.is_seen
    assert_equal 'Mon titre manuel', episode.french_title
    assert_equal 'Ma traduction.', episode.abstract
  end

  test 'a second part already assigned elsewhere rolls back the entire completion' do
    season = @root.children.create!(record_kind: 'season', rank: 10, french_title: 'Saison 10',
                                    language_version: @root.language_version)
    other = season.children.create!(record_kind: 'episode', rank: 99, french_title: 'Autre fiche',
                                    language_version: @root.language_version)
    CatalogueEpisodeLink.create!(record: other, provider: 'tmdb', external_series_id: 987,
                                  external_episode_id: 103, local_season_number: 10, external_season_number: 10,
                                  local_episode_number: 99, external_episode_number: 4, evidence: {})
    assert_no_difference(['Record.count', 'CatalogueEpisodeLink.count', 'VideoAsset.count']) do
      assert_raises(ArgumentError) { complete }
    end
    assert_empty season.children.where(rank: 1)
  end
end
