require 'test_helper'

class EncoderProjects::SeriesCatalogueCompletionTest < ActiveSupport::TestCase
  setup do
    language = LanguageVersion.find_or_create_by!(short_name: 'IND') { |item| item.long_name = 'Indéterminée' }
    @root = Record.create!(french_title: 'Esprits criminels', original_title: 'Criminal Minds',
                           record_kind: 'series', language_version: language)
    rows = [[101, 0, 1, 'Présentation', 'Preview'], [102, 6, 22, 'Chambre noire', 'Out of the Light'],
            [103, 6, 23, 'Nouvelle enquête', 'Another Case']]
    @snapshot = { 'tmdb_series_id' => 4057, 'source_url' => 'https://www.themoviedb.org/tv/4057',
                  'series' => { 'seasons' => [{ 'season_number' => 0 }, { 'season_number' => 6 }] },
                  'episodes' => rows.map do |id, season, episode, french, original|
                    { 'tmdb_episode_id' => id, 'season_number' => season, 'episode_number' => episode,
                      'title_fr' => french, 'title_original' => original, 'overview_fr' => 'Synopsis court.',
                      'first_air_date' => '2011-05-04', 'reference_runtime_minutes' => 42 }
                  end }
  end

  def service
    EncoderProjects::SeriesCatalogueCompletion.new(root: @root, snapshot: @snapshot)
  end

  test 'creates every documented season and episode without inventing copies or measured media' do
    assert_difference('Record.count', 5) do
      assert_difference('CatalogueEpisodeLink.count', 3) do
        assert_no_difference('VideoAsset.count') { service.call }
      end
    end
    assert_equal [0, 6], @root.children.order(:rank).pluck(:rank)
    @root.descendants.where(record_kind: 'episode').each do |episode|
      assert_equal false, episode.is_recorded
      assert_equal false, episode.is_available
      assert_equal false, episode.effective_state(:is_seen)
      assert_equal 'IND', episode.language_version.short_name
      assert_empty episode.media
      assert_nil episode.length_in_mn
      assert_equal 2011, episode.year
    end
    assert_no_difference(['Record.count', 'CatalogueEpisodeLink.count', 'VideoAsset.count']) { service.call }
  end

  test 'preserves an existing viewing state and manually edited synopsis' do
    season = @root.children.create!(record_kind: 'season', rank: 6, french_title: 'Saison 06',
                                    language_version: @root.language_version)
    episode = season.children.create!(record_kind: 'episode', rank: 22, french_title: 'Chambre noire',
                                      language_version: @root.language_version, is_seen: true, abstract: 'Résumé manuel.')
    service.call
    assert_equal true, episode.reload.is_seen
    assert_equal 'Résumé manuel.', episode.abstract
    assert_equal 'manual', episode.abstract_provenance['kind']
  end

  test 'a numbering conflict rolls back the entire catalogue completion' do
    season = @root.children.create!(record_kind: 'season', rank: 6, french_title: 'Saison 06',
                                    language_version: @root.language_version)
    season.children.create!(record_kind: 'episode', rank: 22, french_title: 'Une autre œuvre',
                             language_version: @root.language_version)
    assert_no_difference(['Record.count', 'CatalogueEpisodeLink.count', 'VideoAsset.count']) do
      assert_raises(ArgumentError) { service.call }
    end
    assert_empty @root.children.where(rank: 0)
  end
  test 'a confirmed catalogue identity preserves a later manual title correction' do
    service.call
    episode = @root.descendants.find_by!(record_kind: 'episode', rank: 22)
    episode.update!(french_title: 'Mon titre corrigé', original_title: '')
    assert_no_difference(['Record.count', 'CatalogueEpisodeLink.count']) { service.call }
    assert_equal 'Mon titre corrigé', episode.reload.french_title
  end

end
