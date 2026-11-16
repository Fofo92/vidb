require 'test_helper'
require 'minitest/mock'

class EncoderDesktopLaunchTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(email: 'desktop-launch@example.com', password: 'password')
    @language = LanguageVersion.find_or_create_by!(short_name: 'IND') { |row| row.long_name = 'Indéterminée' }
    @record = Record.create!(french_title: 'Film choisi', record_kind: 'standalone_video', language_version: @language)
    @configuration = { 'url' => 'https://vidb.test', 'token' => 'a' * 64, 'user_id' => @user.id }
    url = EncoderProjects::LaunchTicket.issue(record: @record, user: @user, url: @configuration['url'])
    @ticket = URI.decode_www_form(URI(url).query).to_h.fetch('ticket')
    @context = EncoderProjects::LaunchTicket.read(@ticket, user: @user)
    @headers = { 'Authorization' => "Bearer #{@configuration['token']}" }
  end

  test 'the browser preparation requires login and opens no physical copy' do
    get encoder_project_preparation_path(@record)
    assert_redirected_to new_user_session_path
    sign_in @user
    EncoderProjects::Settings.stub(:read, @configuration) do
      assert_no_difference ['VideoAsset.count', 'ReconciliationCase.count'] do
        get encoder_project_preparation_path(@record)
      end
    end
    assert_response :success
    assert_select 'button[type="button"][data-encoder-launch-url-param^="vidb-encoder://prepare?"]', text: 'Ouvrir video_encoder'
  end

  test 'context resolution requires the bridge credential and the matching account' do
    EncoderProjects::Settings.stub(:read, @configuration) do
      post '/encoder_projects/launch_binding', params: { launch_token: @ticket }, as: :json
      assert_response :unauthorized
      post '/encoder_projects/launch_binding', params: { launch_token: @ticket }, headers: @headers, as: :json
      assert_response :success
      assert_equal @context['project_id'], response.parsed_body['project_id']
      assert_equal @record.id, response.parsed_body['record_id']
      post '/encoder_projects/launch_binding', params: { launch_token: 'invalid' }, headers: @headers, as: :json
      assert_response :unprocessable_content
    end
  end

  test 'a browser-issued launch resolves through the configured bridge on the same origin' do
    sign_in @user
    host! 'vidb.test'
    https!
    EncoderProjects::Settings.stub(:read, @configuration) do
      get encoder_project_preparation_path(@record)
      assert_response :success
      url = css_select('button[type="button"][data-encoder-launch-url-param^="vidb-encoder://prepare?"]').sole['data-encoder-launch-url-param']
      ticket = URI.decode_www_form(URI(url).query).to_h.fetch('ticket')
      post '/encoder_projects/launch_binding', params: { launch_token: ticket }, headers: @headers, as: :json
      assert_response :success
      assert_equal @record.id, response.parsed_body['record_id']
    end
  end

  test 'the chosen record binds without creating an available copy and repeated identification is idempotent' do
    project = { project_id: @context['project_id'], project_path: '/videos/source.json',
                output_path: '/videos/source.mkv', source_paths: ['/commun/to_be_cut/source.m2t'] }
    EncoderProjects::Settings.stub(:read, @configuration) do
      assert_no_difference 'VideoAsset.count' do
        post '/encoder_projects/launch_binding', params: { launch_token: @ticket, project: project },
                                                 headers: @headers, as: :json
        assert_response :success
        assert_equal 'identified', response.parsed_body['status']
        assert_equal @record.id, response.parsed_body.dig('binding', 'record_id')
      end
      assert_no_difference 'ReconciliationCase.count' do
        post '/encoder_projects/launch_binding', params: { launch_token: @ticket, project: project },
                                                 headers: @headers, as: :json
        assert_response :success
      end
    end
  end

  test 'a ticket cannot be reused with another project identifier' do
    project = { project_id: SecureRandom.uuid, project_path: '/videos/source.json',
                output_path: '/videos/source.mkv', source_paths: ['/commun/source.m2t'] }
    EncoderProjects::Settings.stub(:read, @configuration) do
      assert_no_difference ['VideoAsset.count', 'ReconciliationCase.count'] do
        post '/encoder_projects/launch_binding', params: { launch_token: @ticket, project: project },
                                                 headers: @headers, as: :json
      end
    end
    assert_response :unprocessable_content
  end

  test 'a browser account different from the configured operator gets an explanation' do
    sign_in @user
    EncoderProjects::Settings.stub(:read, @configuration.merge('user_id' => @user.id + 1)) do
      get encoder_project_preparation_path(@record)
    end
    assert_redirected_to record_path(@record)
    assert_match(/autre compte/, flash[:alert])
  end
end
