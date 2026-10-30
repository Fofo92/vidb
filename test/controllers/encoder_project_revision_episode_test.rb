require 'test_helper'

class EncoderProjectRevisionEpisodeTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(email: 'episode-revision@example.com', password: 'password')
    @language = LanguageVersion.find_or_create_by!(short_name: 'IND') { |item| item.long_name = 'Indéterminée' }
    @series = Record.create!(french_title: 'Série locale', record_kind: 'series', language_version: @language)
    @season = @series.children.create!(french_title: 'Saison 02', record_kind: 'season', rank: 2,
                                       language_version: @language)
    @right = episode(3, 'Épisode à choisir')
    @wrong = episode(4, 'Épisode choisi précédemment')
    @project = { 'project_id' => SecureRandom.uuid, 'project_path' => '/videos/Serie.json',
                 'output_path' => '/videos/Serie.mkv', 'source_paths' => ['/commun/Serie - S02 E03 - Episode.m2t'] }
    EncoderProjects::LocalRecordSelection.call(user: @user, url: 'https://www.example.com',
                                               project: @project, record: @wrong)
    result = EncoderProjects::Identification.new(user: @user, url: 'https://www.example.com').call(@project)
    @token = URI.decode_www_form(URI(result.fetch(:selection_url)).query).to_h.fetch('request_token')
    sign_in @user
  end

  def episode(rank, title)
    @season.children.create!(french_title: title, record_kind: 'episode', rank: rank, year: 2024,
                              language_version: @language)
  end

  def submit_revision(confirmed:)
    get encoder_projects_episode_path, params: { request_token: @token, q: @series.french_title,
                                                series_id: @series.id.to_s, season_number: '2',
                                                episode_number: '3', enrich: '0' }
    assert_response :success
    proposal = nil
    assert_select 'input[name="proposal_token"]' do |inputs|
      proposal = inputs.first['value']
    end
    post encoder_projects_episode_path, params: { request_token: @token, proposal_token: proposal,
                                                 encoder_window: '1', series_id: @series.id,
                                                 title: @right.french_title, language_version: 'IND',
                                                 confirm_replacement: confirmed ? '1' : '0' }
  end

  test 'an episode can replace the wrong choice through the existing preparation form' do
    assert_no_difference ['Record.count', 'VideoAsset.count'] do
      submit_revision(confirmed: true)
    end
    assert_redirected_to record_path(@right, encoder_prepared: 1)
    assert_equal @right.id, EncoderProjects::Binding.current(@project['project_id'])['record_id']
  end

  test 'the previous episode stays bound if replacement is not confirmed' do
    submit_revision(confirmed: false)
    assert_response :unprocessable_content
    assert_equal @wrong.id, EncoderProjects::Binding.current(@project['project_id'])['record_id']
  end
end
