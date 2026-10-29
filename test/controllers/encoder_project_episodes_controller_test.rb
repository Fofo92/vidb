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
    assert_select '.encoder-episode-form .encoder-field input[name="title"]'
    assert_select '.encoder-episode-form .encoder-field input[name="original_title"]'
    assert_select '.encoder-field-wide textarea[name="abstract"]'
    assert_select '.encoder-field select[name="gender_ids[]"]'
    assert_select '.encoder-field select[name="country_ids[]"]'
    assert_select 'select[name="series_id"] option', text: /Cat's Eyes/
  end

  test 'a natural French source name redirects before any film or unified title search' do
    project = { 'project_id' => SecureRandom.uuid, 'project_path' => '/videos/montage.json',
                'output_path' => '/videos/montage.mkv',
                'source_paths' => ['/commun/to_be_cut/La stagiaire — Saison 9, épisode 6.m2t'] }
    token = EncoderProjects::CatalogueScope.issue(user: @user, project: project)
    assert_no_difference(['Record.count', 'VideoAsset.count']) do
      EncoderProjects::FilmCatalogue.stub(:new, -> { flunk 'No film search for an episode' }) do
        EncoderProjects::SeriesCatalogueSearch.stub(:new, -> { flunk 'Episode routing must happen first' }) do
          get encoder_projects_catalogue_path,
              params: { request_token: token }
        end
      end
    end
    assert_redirected_to encoder_projects_episode_path(request_token: token)
  end

  test 'a typed episode routes a generic capture and preserves its target through the redirect' do
    project = { 'project_id' => SecureRandom.uuid, 'project_path' => '/videos/montage.json',
                'output_path' => '/videos/montage.mkv', 'source_paths' => ['/commun/capture.m2t'] }
    token = EncoderProjects::CatalogueScope.issue(user: @user, project: project)
    series = Record.create!(french_title: 'La stagiaire', record_kind: 'series',
                            language_version: @series.language_version)
    catalogue = Object.new
    catalogue.define_singleton_method(:warnings) { [] }
    catalogue.define_singleton_method(:call) do |selected, numbers|
      raise 'Wrong episode lookup' unless selected.id == series.id &&
                                         [numbers.season, numbers.episode, numbers.title] == [9, 6, 'Errance']

      []
    end
    assert_no_difference(['Record.count', 'VideoAsset.count']) do
      EncoderProjects::FilmCatalogue.stub(:new, -> { flunk 'No film search for a typed episode' }) do
        get encoder_projects_catalogue_path,
            params: { request_token: token, q: 'La stagiaire - S09 E06 - Errance' }
      end
      assert_response :redirect
      EncoderProjects::EpisodeCatalogue.stub(:new, -> { catalogue }) { follow_redirect! }
    end
    assert_response :success
    assert_select 'input[name="title"][value="Errance"]'
  end

  test 'a full episode query on the episode form replaces the source target' do
    catalogue = Object.new
    catalogue.define_singleton_method(:warnings) { [] }
    catalogue.define_singleton_method(:call) do |_series, numbers|
      raise 'Old episode target was retained' unless [numbers.season, numbers.episode, numbers.title] == [3, 4, 'Suite']

      []
    end
    EncoderProjects::EpisodeCatalogue.stub(:new, -> { catalogue }) do
      get encoder_projects_episode_path, params: { request_token: @token, q: "Cat's Eyes - S03 E04 - Suite" }
    end
    assert_response :success
    assert_select 'input[name="title"][value="Suite"]'
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
    calls = []
    catalogue.define_singleton_method(:from_source) do |id, query, numbers, url|
      calls << [id, query, numbers.season, numbers.episode, url]
      [candidate]
    end
    catalogue.define_singleton_method(:warnings) { [] }
    assert_no_difference(['Record.count', 'VideoAsset.count']) do
      EncoderProjects::MissingSeriesCatalogue.stub(:new, -> { catalogue }) do
        get encoder_projects_episode_path, params: { request_token: token }
      end
    end
    assert_response :success
    assert_equal [[nil, 'Esprits criminels', 6, 22, nil]], calls
    assert_select 'input[type="submit"][value="Créer la série complète et préparer S06 E22"]'
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

  def existing_series_scope
    project, candidate = missing_series_scope
    candidate.delete('series_candidate')
    candidate['series_id'] = @series.id
    candidate['catalogue_completion'] = { 'record_id' => @series.id, 'tmdb_id' => 4057 }
    [project, candidate]
  end

  test 'existing series completion is proposed checked and makes no writes on consultation' do
    @series.update!(french_title: 'Esprits criminels')
    project, candidate = existing_series_scope
    token = EncoderProjects::CatalogueScope.issue(user: @user, project: project)
    catalogue = Object.new
    catalogue.define_singleton_method(:call) { |_series, _numbers| [candidate] }
    catalogue.define_singleton_method(:warnings) { [] }
    assert_no_difference(['Record.count', 'VideoAsset.count']) do
      EncoderProjects::EpisodeCatalogue.stub(:new, -> { catalogue }) do
        get encoder_projects_episode_path, params: { request_token: token, series_id: @series.id, enrich: '1' }
      end
    end
    assert_select 'input[type="checkbox"][name="complete_catalogue"][checked]', count: 1
  end

  test 'existing series completion reuses existing episode and preserves its states on replay' do
    project, candidate = existing_series_scope
    @series.update!(french_title: 'Esprits criminels')
    season = @series.children.create!(french_title: 'Saison 06', rank: 6, record_kind: 'season',
                                      language_version: @series.language_version)
    episode = season.children.create!(french_title: 'Chambre noire', rank: 22, record_kind: 'episode',
                                      language_version: @series.language_version, is_seen: true,
                                      is_recorded: false, is_available: false)
    before = episode.attributes.slice('is_seen', 'is_recorded', 'is_available', 'seen_state_confirmed_at')
    token = EncoderProjects::CatalogueScope.issue(user: @user, project: project, candidate: candidate)
    snapshot = Object.new
    result = complete_snapshot
    snapshot.define_singleton_method(:call) { result }
    parameters = { proposal_token: token, series_id: @series.id, title: 'Chambre noire', complete_catalogue: '1' }
    CatalogEnrichment::TmdbSeriesSnapshot.stub(:new, ->(**_options) { snapshot }) do
      assert_difference('Record.count', 3) do
        assert_no_difference('VideoAsset.count') { post encoder_projects_episode_path, params: parameters }
      end
      assert_redirected_to record_path(episode)
      assert_equal before, episode.reload.attributes.slice(*before.keys)
      fresh = @series.descendants.where(record_kind: 'episode').where.not(id: episode.id)
      assert_equal 2, fresh.count
      fresh.each do |item|
        assert_equal false, item.is_recorded
        assert_equal false, item.is_available
        assert_equal false, item.effective_state(:is_seen)
        assert_empty item.video_assets
      end
      assert_no_difference(['Record.count', 'CatalogueEpisodeLink.count', 'VideoAsset.count']) do
        post encoder_projects_episode_path, params: parameters
      end
    end
  end

  test 'completion cannot be redirected to another local series by changing the form selection' do
    project, candidate = existing_series_scope
    token = EncoderProjects::CatalogueScope.issue(user: @user, project: project, candidate: candidate)
    other = Record.create!(french_title: 'Autre série', record_kind: 'series',
                           language_version: @series.language_version)
    CatalogEnrichment::TmdbSeriesSnapshot.stub(:new, ->(**_options) { flunk 'No source call for another series' }) do
      assert_no_difference(['Record.count', 'CatalogueEpisodeLink.count', 'VideoAsset.count']) do
        post encoder_projects_episode_path, params: { proposal_token: token, series_id: other.id,
                                                     title: 'Chambre noire', complete_catalogue: '1' }
      end
    end
    assert_response :unprocessable_content
  end

  test 'unchecked completion prepares only the requested episode without loading all seasons' do
    project, candidate = existing_series_scope
    token = EncoderProjects::CatalogueScope.issue(user: @user, project: project, candidate: candidate)
    CatalogEnrichment::TmdbSeriesSnapshot.stub(:new, ->(**_options) { flunk 'Completion was declined' }) do
      assert_difference('Record.count', 2) do
        post encoder_projects_episode_path, params: { proposal_token: token, series_id: @series.id,
                                                     title: 'Chambre noire', complete_catalogue: '0' }
      end
    end
    assert_response :redirect
    assert_equal 1, @series.descendants.where(record_kind: 'episode').count
  end

  test 'a conflict in another episode rolls back the whole existing series preparation' do
    project, candidate = existing_series_scope
    season = @series.children.create!(french_title: 'Saison 06', rank: 6, record_kind: 'season',
                                      language_version: @series.language_version)
    conflict = season.children.create!(french_title: 'Une autre œuvre', rank: 23, record_kind: 'episode',
                                        language_version: @series.language_version, is_seen: true)
    token = EncoderProjects::CatalogueScope.issue(user: @user, project: project, candidate: candidate)
    snapshot = Object.new
    result = complete_snapshot
    snapshot.define_singleton_method(:call) { result }
    CatalogEnrichment::TmdbSeriesSnapshot.stub(:new, ->(**_options) { snapshot }) do
      assert_no_difference(['Record.count', 'CatalogueEpisodeLink.count', 'VideoAsset.count']) do
        post encoder_projects_episode_path, params: { proposal_token: token, series_id: @series.id,
                                                     title: 'Chambre noire', complete_catalogue: '1' }
      end
    end
    assert_response :unprocessable_content
    assert_equal 'Une autre œuvre', conflict.reload.french_title
    assert_equal true, conflict.is_seen
    assert_empty @series.children.where(rank: 0)
  end

  test 'a direct TMDB URL enriches the selected local series without writing records' do
    catalogue = Object.new
    calls = []
    catalogue.define_singleton_method(:call) do |series, numbers, tmdb_series_id:|
      calls << [series.id, numbers.season, numbers.episode, tmdb_series_id]
      []
    end
    catalogue.define_singleton_method(:warnings) { [] }
    EncoderProjects::EpisodeCatalogue.stub(:new, -> { catalogue }) do
      assert_no_difference(['Record.count', 'CatalogueEpisodeLink.count', 'VideoAsset.count']) do
        get encoder_projects_episode_path, params: { request_token: @token, series_id: @series.id,
             season_number: '12', episode_number: '11', source_url: 'https://www.themoviedb.org/tv/42083' }
      end
    end
    assert_response :success
    assert_equal [[@series.id, 12, 11, 42083]], calls
    assert_select 'input[name="source_url"][value="https://www.themoviedb.org/tv/42083"]'
  end

  test 'an invalid source URL displays a warning without an automatic external search' do
    EncoderProjects::EpisodeCatalogue.stub(:new, -> { flunk 'Invalid URL must not fall back to search' }) do
      get encoder_projects_episode_path, params: { request_token: @token, source_url: 'https://example.org/tv/42' }
    end
    assert_response :success
    assert_match 'Saisis une URL TMDB', response.body
  end

  test 'an explicit URL also works when the local series is missing' do
    catalogue = Object.new
    calls = []
    catalogue.define_singleton_method(:from_source) do |id, _query, numbers, _url|
      calls << [id, numbers.season, numbers.episode]
      []
    end
    catalogue.define_singleton_method(:warnings) { [] }
    EncoderProjects::MissingSeriesCatalogue.stub(:new, -> { catalogue }) do
      get encoder_projects_episode_path, params: { request_token: @token, q: 'Une série absente',
           source_url: 'https://www.themoviedb.org/tv/42083' }
    end
    assert_response :success
    assert_equal [[42083, 2, 1]], calls
  end

  test 'an episode URL shows external numbering and requires confirmation without writing records' do
    reference = { 'series_id' => 42083, 'season' => 14, 'episode' => 2, 'episode_id' => 987 }
    candidate = { 'title' => 'Chasse aux fantômes', 'tmdb_episode_reference' => reference }
    catalogue = Object.new
    calls = []
    catalogue.define_singleton_method(:call) do |_series, numbers, **options|
      calls << [numbers.season, numbers.episode, options]
      [candidate]
    end
    catalogue.define_singleton_method(:warnings) { [] }
    EncoderProjects::EpisodeCatalogue.stub(:new, -> { catalogue }) do
      assert_no_difference(['Record.count', 'CatalogueEpisodeLink.count', 'VideoAsset.count']) do
        get encoder_projects_episode_path, params: { request_token: @token, series_id: @series.id,
             season_number: '12', episode_number: '11',
             source_url: 'https://www.themoviedb.org/tv/42083/season/14/episode/2' }
      end
    end
    assert_response :success
    assert_equal [[12, 11, { tmdb_series_id: 42083, tmdb_episode: { 'season' => 14, 'episode' => 2 } }]], calls
    assert_select 'input[type="checkbox"][name="confirm_tmdb_episode_mapping"][required]'
    assert_select 'input[name="confirm_tmdb_episode_mapping"][checked]', count: 0
    assert_select 'input[name="complete_catalogue"]', count: 0
    assert_match 'S14 E02', response.body
  end

  test 'a direct POST cannot bypass correspondence confirmation' do
    candidate = { 'series_id' => @series.id, 'season' => 2, 'episode' => 1, 'title' => 'Chasse aux fantômes',
                  'tmdb_episode_reference' => { 'series_id' => 42083, 'season' => 14, 'episode' => 2, 'episode_id' => 987 } }
    scope = EncoderProjects::CatalogueScope.read(@token, user: @user)
    token = EncoderProjects::CatalogueScope.issue(user: @user, project: scope.fetch('project'), candidate: candidate)
    assert_no_difference(['Record.count', 'CatalogueEpisodeLink.count', 'VideoAsset.count']) do
      post encoder_projects_episode_path, params: { proposal_token: token, series_id: @series.id,
                                                   title: 'Chasse aux fantômes', complete_catalogue: '1' }
    end
    assert_response :unprocessable_content
    assert_match 'Confirme la correspondance', response.body
  end

end
