require 'test_helper'
require 'minitest/mock'

class EncoderProjectEpisodesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(email: 'episode-encoder@example.com', password: 'password')
    language = LanguageVersion.find_or_create_by!(short_name: 'IND') { |item| item.long_name = 'Indéterminée' }
    @series = Record.create!(french_title: "Cat's Eyes", record_kind: 'series', language_version: language)
    project = { 'project_id' => SecureRandom.uuid, 'project_path' => '/videos/montage.json',
                'output_path' => '/videos/montage.mkv',
                'source_paths' => ["/commun/to_be_cut/Cat's Eyes - S02 E01 - Un nouvel espoir.m2t"] }
    @token = EncoderProjects::CatalogueScope.issue(user: @user, project: project)
    sign_in @user
  end

  test 'an old film link redirects to the episode form without creating records' do
    assert_no_difference('Record.count') do
      get encoder_projects_catalogue_path, params: { request_token: @token }
    end
    assert_redirected_to encoder_projects_episode_path(request_token: @token)
    catalogue = Object.new
    catalogue.define_singleton_method(:call) { |_series, _numbers| [] }
    catalogue.define_singleton_method(:warnings) { [] }
    EncoderProjects::EpisodeCatalogue.stub(:new, -> { catalogue }) { follow_redirect! }
    assert_response :success
    assert_select 'input[name="title"][value="Un nouvel espoir"]'
    assert_select 'input[name="original_title"]'
    assert_select 'select[name="series_id"] option', text: /Cat's Eyes/
  end

  test 'confirmation creates the hierarchy without a video file' do
    assert_difference('Record.count', 2) do
      assert_no_difference('VideoAsset.count') do
        post encoder_projects_episode_path, params: { request_token: @token, series_id: @series.id,
                                                     title: 'Un nouvel espoir', original_title: 'A New Hope', year: '2026' }
      end
    end
    episode = @series.descendants.find_by!(record_kind: 'episode')
    assert_redirected_to record_path(episode)
    assert_equal 'Un nouvel espoir', episode.french_title
    assert_equal 'A New Hope', episode.original_title
    assert_equal 1, episode.rank
    assert_equal 2, episode.parent.rank
  end

  test 'a different account cannot create records through a copied link' do
    sign_out @user
    sign_in User.create!(email: 'episode-other@example.com', password: 'password')
    assert_no_difference('Record.count') do
      post encoder_projects_episode_path, params: { request_token: @token, series_id: @series.id,
                                                   title: 'Un nouvel espoir', year: '2026' }
    end
    assert_response :unprocessable_content
  end
  def missing_series_scope
    project = { 'project_id' => SecureRandom.uuid, 'project_path' => '/videos/test.json',
                'output_path' => '/videos/test.mkv',
                'source_paths' => ['/commun/to_be_cut/Esprits criminels - S06 E22 - Chambre noire.m2t'] }
    candidate = { 'title' => 'Chambre noire', 'original_title' => 'Out of the Light', 'year' => 2011,
                  'abstract' => 'Une enquête.', 'series_id' => 'tmdb:4057', 'season' => 6, 'episode' => 22,
                  'source' => { 'provider' => 'tmdb', 'url' => 'https://www.themoviedb.org/tv/4057' },
                  'gender_ids' => [], 'country_ids' => [],
                  'series_candidate' => { 'tmdb_id' => 4057, 'french_title' => 'Esprits criminels',
                                          'original_title' => 'Criminal Minds', 'year' => 2005,
                                          'source' => { 'provider' => 'tmdb', 'url' => 'https://www.themoviedb.org/tv/4057' },
                                          'episode_count' => 3, 'season_count' => 2 } }
    [project, candidate]
  end

  def complete_snapshot
    { 'tmdb_series_id' => 4057, 'source_url' => 'https://www.themoviedb.org/tv/4057',
      'series' => { 'seasons' => [{ 'season_number' => 0 }, { 'season_number' => 6 }] },
      'episodes' => [[101, 0, 1, 'Présentation'], [102, 6, 22, 'Chambre noire'], [103, 6, 23, 'Autre enquête']].map do |id, season, number, title|
        { 'tmdb_episode_id' => id, 'season_number' => season, 'episode_number' => number,
          'title_fr' => title, 'title_original' => title, 'overview_fr' => 'Synopsis court.', 'first_air_date' => '2011-05-04' }
      end }
  end

  test 'missing local series triggers a read only external proposal' do
    project, candidate = missing_series_scope
    token = EncoderProjects::CatalogueScope.issue(user: @user, project: project)
    catalogue = Object.new
    catalogue.define_singleton_method(:call) { |_query, _numbers| [candidate] }
    catalogue.define_singleton_method(:warnings) { [] }
    assert_no_difference(['Record.count', 'VideoAsset.count']) do
      EncoderProjects::MissingSeriesCatalogue.stub(:new, -> { catalogue }) do
        get encoder_projects_episode_path, params: { request_token: token }
      end
    end
    assert_response :success
    assert_select 'input[type="submit"][value="Créer la série complète et préparer cet épisode"]'
  end

  test 'confirmation creates the full catalogue then binds only the requested episode' do
    project, candidate = missing_series_scope
    token = EncoderProjects::CatalogueScope.issue(user: @user, project: project, candidate: candidate)
    snapshot = Object.new
    result = complete_snapshot
    snapshot.define_singleton_method(:call) { result }
    CatalogEnrichment::TmdbSeriesSnapshot.stub(:new, ->(**_options) { snapshot }) do
      assert_difference('Record.count', 6) do
        assert_no_difference('VideoAsset.count') do
          post encoder_projects_episode_path, params: { proposal_token: token, series_id: 'new', title: 'Chambre noire' }
        end
      end
      root = Record.find_by!(french_title: 'Esprits criminels', record_kind: 'series')
      assert_equal 3, root.descendants.where(record_kind: 'episode').count
      episode = root.descendants.find_by!(record_kind: 'episode', rank: 22)
      assert_redirected_to record_path(episode)
      assert_equal false, episode.is_seen
      assert_no_difference(['Record.count', 'VideoAsset.count', 'CatalogueEpisodeLink.count']) do
        post encoder_projects_episode_path, params: { proposal_token: token, series_id: 'new', title: 'Chambre noire' }
      end
    end
  end

end
