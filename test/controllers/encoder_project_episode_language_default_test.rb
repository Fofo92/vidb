require 'test_helper'
require 'minitest/mock'

class EncoderProjectEpisodeLanguageDefaultTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(email: 'episode-language-default@example.com', password: 'password')
    %w[IND VF VMST].each do |code|
      LanguageVersion.find_or_create_by!(short_name: code) { |item| item.long_name = code }
    end
    @vf = LanguageVersion.find_by!(short_name: 'VF')
    @series = Record.create!(french_title: 'MacGyver', record_kind: 'series', language_version: @vf)
    season = @series.children.create!(french_title: 'Saison 1', rank: 1, record_kind: 'season', language_version: @vf)
    @episode = season.children.create!(french_title: 'Superstition', original_title: 'Cigar Cutter',
                                       rank: 21, year: 2016, record_kind: 'episode', language_version: @vf)
    @project = { 'project_id' => SecureRandom.uuid, 'project_path' => '/videos/montage.json',
                 'output_path' => '/videos/montage.mkv',
                 'source_paths' => ['/commun/to_be_cut/MacGyver - S01 E21.m2t'] }
    @origin = { 'status' => 'foreign', 'language' => 'en', 'provider' => 'tmdb' }
    sign_in @user
  end

  def open_form(hint)
    project = hint ? @project.merge('language_hint' => hint) : @project
    @token = EncoderProjects::CatalogueScope.issue(user: @user, project: project)
    EncoderProjects::OriginalLanguage.stub(:call, @origin) do
      get encoder_projects_episode_path,
          params: { request_token: @token, series_id: @series.id, enrich: '0' }
    end
    assert_response :success
  end

  test 'the existing episode VF takes priority over the montage VMST hint' do
    open_form('VMST')
    assert_select 'select[name="language_version"] option[selected][value="VF"]', count: 1
    assert_equal @vf, @episode.reload.language_version
  end

  test 'a proven French original stays VF despite a multilingual source hint' do
    @origin = { 'status' => 'french', 'language' => 'fr', 'provider' => 'tmdb' }
    open_form('VMST')
    assert_select 'select[name="language_version"] option[selected][value="VF"]', count: 1
  end

  test 'an unknown or absent source hint keeps the existing version as the fallback' do
    [nil, 'IND'].each do |hint|
      open_form(hint)
      assert_select 'select[name="language_version"] option[selected][value="VF"]', count: 1
    end
  end

  test 'the user selected VF remains selected after another field fails validation' do
    open_form('VMST')
    proposal = css_select('input[name="proposal_token"]').first['value']
    post encoder_projects_episode_path,
         params: { request_token: @token, proposal_token: proposal, series_id: '',
                   language_version: 'VF', title: 'Superstition' }
    assert_response :unprocessable_content
    assert_select 'select[name="language_version"] option[selected][value="VF"]', count: 1
    assert_equal @vf, @episode.reload.language_version
  end
end
