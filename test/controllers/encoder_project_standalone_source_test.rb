require 'test_helper'
require 'minitest/mock'

class EncoderProjectStandaloneSourceTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(email: 'standalone-source@example.com', password: 'password')
    LanguageVersion.find_or_create_by!(short_name: 'IND') { |item| item.long_name = 'Indéterminée' }
    @genre = Gender.find_or_create_by!(name: 'Documentaire')
    @country = Country.find_or_create_by!(short_name: 'FR') { |item| item.long_name = 'France' }
    @project = { 'project_id' => SecureRandom.uuid, 'project_path' => '/videos/montage.json',
                 'output_path' => '/videos/montage.mkv',
                 'source_paths' => ['/commun/to_be_cut/Les mystères - S01 E05.m2t'] }
    @token = EncoderProjects::CatalogueScope.issue(user: @user, project: @project)
    @candidate = { 'french_title' => 'Documentaire autonome', 'original_title' => 'Standalone documentary',
                   'year' => 2020, 'record_kind' => 'standalone_video', 'genres_text' => 'Documentaire',
                   'countries_text' => 'France', 'abstract' => 'Résumé du documentaire.',
                   'source' => { 'provider' => 'tmdb', 'tmdb_movie_id' => 123456,
                                 'url' => 'https://www.themoviedb.org/movie/123456' } }
    candidate = @candidate
    @queries = []
    queries = @queries
    @catalogue = Object.new
    @catalogue.define_singleton_method(:call) do |query|
      queries << query
      [candidate]
    end
    @catalogue.define_singleton_method(:warnings) { [] }
    sign_in @user
  end

  def with_film_search(&block)
    EncoderProjects::SeriesCatalogueSearch.stub(:new, -> { flunk 'Unexpected series search' }) do
      EncoderProjects::FilmCatalogue.stub(:new, -> { @catalogue }, &block)
    end
  end

  def displayed_scope
    token = css_select('input[name="request_token"]').first['value']
    EncoderProjects::CatalogueScope.read(token, user: @user)
  end

  test 'a movie URL in the episode form redirects to a film search and keeps the project' do
    assert_no_difference(['Record.count', 'VideoAsset.count']) do
      get encoder_projects_episode_path, params: { request_token: @token,
                                                  source_url: 'https://themoviedb.org/movie/123456-documentaire' }
      assert_response :redirect
      with_film_search { follow_redirect! }
    end
    assert_response :success
    assert_select 'h1', /Identifier l’œuvre/
    assert_equal ['https://www.themoviedb.org/movie/123456'], @queries
    assert_equal @project['project_id'], displayed_scope.fetch('project').fetch('project_id')
    assert_equal @project['source_paths'], displayed_scope.fetch('project').fetch('source_paths')
    assert_equal 'standalone_video', displayed_scope.fetch('project').fetch('work_kind')
  end

  test 'an explicit standalone choice survives another title search' do
    with_film_search do
      get encoder_projects_catalogue_path, params: { request_token: @token, work_kind: 'standalone_video',
                                                   q: 'Documentaire autonome' }
      assert_response :success
      token = css_select('input[name="request_token"]').first['value']
      get encoder_projects_catalogue_path, params: { request_token: token, q: 'Autre recherche' }
    end
    assert_response :success
    assert_equal ['Documentaire autonome', 'Autre recherche'], @queries
  end

  test 'a direct movie query overrides the numbered source without an explicit mode' do
    with_film_search do
      get encoder_projects_catalogue_path, params: { request_token: @token,
                                                   q: 'https://www.themoviedb.org/movie/123456' }
    end
    assert_response :success
    assert_equal 'standalone_video', displayed_scope.fetch('project').fetch('work_kind')
  end

  test 'automatic episode routing still applies before an explicit standalone choice' do
    get encoder_projects_catalogue_path, params: { request_token: @token }
    assert_redirected_to encoder_projects_episode_path(request_token: @token)
  end

  test 'confirmation creates and binds the standalone work from a numbered source' do
    with_film_search do
      get encoder_projects_catalogue_path, params: { request_token: @token,
                                                   q: 'https://www.themoviedb.org/movie/123456' }
    end
    proposal = css_select('input[name="proposal_token"]').first['value']
    token = css_select('input[name="request_token"]').first['value']
    assert_difference('Record.count', 1) do
      assert_no_difference('VideoAsset.count') do
        post encoder_projects_catalogue_path, params: { request_token: token, proposal_token: proposal,
                                                       gender_ids: [@genre.id], country_ids: [@country.id] }
      end
    end
    record = Record.find_by!(french_title: 'Documentaire autonome')
    assert_equal 'standalone_video', record.record_kind
    assert_nil record.parent_id
    assert_equal record.id, EncoderProjects::Binding.current(@project['project_id'])['record_id']
  end

  test 'movie URLs accept both TMDB hosts and never treat a TV URL or foreign host as a movie' do
    url = 'https://www.themoviedb.org/movie/123456'
    assert_equal url, EncoderProjects::FilmCatalogue.tmdb_movie_url(url)
    assert_equal url, EncoderProjects::FilmCatalogue.tmdb_movie_url('https://themoviedb.org/movie/123456-titre?language=fr')
    assert_nil EncoderProjects::FilmCatalogue.tmdb_movie_url('https://www.themoviedb.org/tv/42083')
    assert_nil EncoderProjects::FilmCatalogue.tmdb_movie_url('https://example.org/movie/123456')
  end
end
