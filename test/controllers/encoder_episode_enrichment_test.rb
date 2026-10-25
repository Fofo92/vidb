require 'test_helper'
require 'minitest/mock'

class EncoderEpisodeEnrichmentTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(email: 'episode-enrichment@example.com', password: 'password')
    language = LanguageVersion.find_or_create_by!(short_name: 'IND') { |item| item.long_name = 'Indéterminée' }
    @series = Record.create!(french_title: 'Série test', record_kind: 'series', language_version: language)
    @project = { 'project_id' => SecureRandom.uuid, 'project_path' => '/videos/montage.json',
                 'output_path' => '/videos/montage.mkv',
                 'source_paths' => ['/commun/to_be_cut/Série test - S02 E01 - Le départ.m2t'] }
    @token = EncoderProjects::CatalogueScope.issue(user: @user, project: @project)
    @candidate = { 'series_id' => @series.id, 'season' => 2, 'episode' => 1, 'title' => 'Le départ',
                   'year' => 2025, 'abstract' => '', 'gender_ids' => [], 'country_ids' => [],
                   'source' => { 'provider' => 'wikipedia', 'url' => 'https://fr.wikipedia.org/wiki/Exemple' } }
    sign_in @user
  end

  test 'prepopulates known values and clearly offers editing for unknown fields' do
    candidate = @candidate
    catalogue = Object.new
    catalogue.define_singleton_method(:call) { |_series, _number| [candidate] }
    catalogue.define_singleton_method(:warnings) { [] }
    EncoderProjects::EpisodeCatalogue.stub(:new, -> { catalogue }) do
      get encoder_projects_episode_path, params: { request_token: @token, series_id: @series.id, enrich: '1' }
    end
    assert_response :success
    assert_select 'input[name="year"][value="2025"]'
    assert_select 'textarea[name="abstract"][placeholder="À compléter"]'
    assert_select 'p', text: 'Résumé : à compléter.'
    assert_select 'select[name="country_ids[]"]'
    assert_select 'select[name="language_version"]'
  end

  test 'blank year uses the signed proposal while a missing summary can be typed manually' do
    proposal = EncoderProjects::CatalogueScope.issue(user: @user, project: @project, candidate: @candidate)
    assert_no_difference('VideoAsset.count') do
      post encoder_projects_episode_path, params: { request_token: @token, proposal_token: proposal,
                                                   series_id: @series.id, title: '', year: '', abstract: 'Mon résumé.' }
    end
    episode = @series.descendants.find_by!(record_kind: 'episode')
    assert_redirected_to record_path(episode)
    assert_equal 2025, episode.year
    assert_equal 'Mon résumé.', episode.abstract
    assert_equal 'manual', episode.abstract_provenance['kind']
  end
end
