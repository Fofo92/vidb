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

  private

  def request_catalogue(token: @config['token'])
    EncoderProjects::Settings.stub(:read, @config) do
      get '/encoder_projects/dvd_menu_catalogue/5050582454376', headers: { 'Authorization' => "Bearer #{token}" }
    end
  end

  def create_record(title, kind, **attributes)
    Record.create!(french_title: title, record_kind: kind, language_version: @language, **attributes)
  end
end
