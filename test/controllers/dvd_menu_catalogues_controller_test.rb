require 'test_helper'
require 'minitest/mock'

class DvdMenuCataloguesControllerTest < ActionDispatch::IntegrationTest
  setup do
    user = User.create!(email: 'dvd-menu-encoder@example.com', password: 'password')
    @config = { 'url' => 'https://vidb.test', 'token' => 'a' * 64, 'user_id' => user.id }
    @language = LanguageVersion.find_or_create_by!(short_name: 'IND') { |item| item.long_name = 'Indéterminée' }
  end

  test 'requires the encoder token' do
    request_catalogue(token: 'wrong')
    assert_response :unauthorized
  end

  test 'returns numbered episodes only from the series attached to the EAN' do
    series = create_record('Code Quantum', 'series')
    season = create_record('Saison 2', 'season', parent: series, rank: 2)
    episode = create_record('Aux portes de la mort', 'episode', parent: season, rank: 16)
    other = create_record('Autre série', 'series')
    other_season = create_record('Saison 2', 'season', parent: other, rank: 2)
    create_record('Aux portes de la mort', 'episode', parent: other_season, rank: 16)
    DvdEdition.create!(ean: '5050582454376', record: series)

    assert_no_difference ['Record.count', 'DvdEdition.count', 'DvdContent.count', 'VideoAsset.count'] do
      request_catalogue
    end
    assert_response :success
    assert_equal 'Code Quantum', response.parsed_body.fetch('series_title')
    assert_equal [[episode.id, 2, 16]], response.parsed_body.fetch('episodes').map { |row|
      row.values_at('record_id', 'season', 'episode')
    }
  end

  test 'unknown EAN has no catalogue' do
    request_catalogue
    assert_response :not_found
  end

  test 'finds a series by title and retrieves its catalogue without an EAN' do
    series = create_record('Code Quantum', 'series')
    season = create_record('Saison 2', 'season', parent: series, rank: 2)
    episode = create_record('Aux portes de la mort', 'episode', parent: season, rank: 16)
    create_record('Code Quantum', 'standalone_video')

    EncoderProjects::Settings.stub(:read, @config) do
      get '/encoder_projects/dvd_menu_series', params: { q: 'Code Quantum' }, headers: encoder_headers
      assert_response :success
      assert_equal [series.id], response.parsed_body.fetch('series').pluck('id')
      get '/encoder_projects/dvd_menu_catalogue', params: { series_id: series.id }, headers: encoder_headers
      assert_response :success
      assert_equal [episode.id], response.parsed_body.fetch('episodes').pluck('record_id')
    end
  end

  test 'binds the explicitly chosen episode even if the filename suggests another series' do
    series = create_record('Code Quantum', 'series')
    season = create_record('Saison 2', 'season', parent: series, rank: 2)
    episode = create_record('Aux portes de la mort', 'episode', parent: season, rank: 16)
    project = { project_id: '4d013c0a-7b54-4a67-aef2-7e1af7f6d410',
                project_path: '/videos/Autre série S02E16.json',
                output_path: '/videos/Autre série S02E16.mkv', source_paths: ['/commun/dvd.mkv'] }
    EncoderProjects::Settings.stub(:read, @config) do
      post '/encoder_projects/dvd_menu_selection', params: { record_id: episode.id, project: project },
                                                  as: :json, headers: encoder_headers
    end
    assert_response :success
    assert_equal episode.id, response.parsed_body.dig('binding', 'record_id')
  end

  test 'reopens a stored scan and loads the attached series by preparation ID' do
    series = create_record('Code Quantum', 'series')
    season = create_record('Saison 2', 'season', parent: series, rank: 2)
    episode = create_record('Aux portes de la mort', 'episode', parent: season, rank: 16)
    preparation = DvdPreparation.create!(ean: '5050582454376', announced_content_count: 4)
    DvdEdition.create!(ean: preparation.ean, record: series)

    EncoderProjects::Settings.stub(:read, @config) do
      get '/encoder_projects/dvd_menu_preparations'
      assert_response :unauthorized
      get '/encoder_projects/dvd_menu_preparations', headers: encoder_headers
      assert_response :success
      assert_includes response.parsed_body.fetch('preparations'),
                      { 'id' => preparation.id, 'title' => 'Code Quantum', 'announced_count' => 4,
                        'series_ready' => true }
      get '/encoder_projects/dvd_menu_catalogue', params: { preparation_id: preparation.id }, headers: encoder_headers
      assert_response :success
      assert_equal [episode.id], response.parsed_body.fetch('episodes').pluck('record_id')
    end
  end

  private

  def encoder_headers
    { 'Authorization' => "Bearer #{@config.fetch('token')}" }
  end

  def request_catalogue(token: @config['token'])
    EncoderProjects::Settings.stub(:read, @config) do
      get '/encoder_projects/dvd_menu_catalogue/5050582454376', headers: { 'Authorization' => "Bearer #{token}" }
    end
  end

  def create_record(title, kind, **attributes)
    Record.create!(french_title: title, record_kind: kind, language_version: @language, **attributes)
  end
end
