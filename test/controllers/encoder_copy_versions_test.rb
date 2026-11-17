require 'test_helper'
require 'minitest/mock'

class EncoderCopyVersionsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(email: 'copy-version@example.com', password: 'password')
    language = LanguageVersion.find_or_create_by!(short_name: 'VM') { |row| row.long_name = 'Multilingue' }
    @record = Record.create!(french_title: 'Monstres gentils', record_kind: 'standalone_video',
                             language_version: language)
    @asset = VideoAsset.create!(record: @record, status: 'present', language_version: language,
                                last_known_path: '/videos/Monstres gentils.mkv')
    @configuration = { 'url' => 'https://vidb.test', 'token' => 'a' * 64, 'user_id' => @user.id }
    host! 'vidb.test'
    https!
  end

  def ticket
    url = EncoderProjects::LaunchTicket.issue(record: @record, user: @user,
                                              url: @configuration['url'], source_copy: @asset)
    URI.decode_www_form(URI(url).query).to_h.fetch('ticket')
  end

  test 'the copy action requires login and opens a signed desktop preparation without modifying a copy' do
    get encoder_copy_version_path(@record, @asset)
    assert_redirected_to new_user_session_path
    sign_in @user
    before = [@record.attributes, @asset.attributes]
    EncoderProjects::Settings.stub(:read, @configuration) do
      assert_no_difference ['VideoAsset.count', 'ReconciliationCase.count'] do
        get encoder_copy_version_path(@record, @asset)
      end
    end
    assert_response :success
    assert_select 'h1', 'Changer de version'
    assert_select 'button[data-encoder-launch-url-param^="vidb-encoder://prepare?"]', count: 1
    assert_equal before, [@record.reload.attributes, @asset.reload.attributes]
  end

  test 'the authenticated desktop receives the selected copy and cannot substitute another source' do
    token = ticket
    EncoderProjects::Settings.stub(:read, @configuration) do
      post '/encoder_projects/launch_binding', params: { launch_token: token }, as: :json
      assert_response :unauthorized
      headers = { 'Authorization' => "Bearer #{@configuration['token']}" }
      post '/encoder_projects/launch_binding', params: { launch_token: token }, headers: headers, as: :json
      assert_response :success
      context = response.parsed_body
      assert_equal @record.id, context['record_id']
      assert_equal @asset.id, context.dig('source_copy', 'id')
      assert_equal @asset.last_known_path, context.dig('source_copy', 'path')
      project = { project_id: context['project_id'], project_path: '/videos/new.json',
                  output_path: '/videos/new.mkv', source_paths: ['/videos/another.mkv'] }
      assert_no_difference 'ReconciliationCase.count' do
        post '/encoder_projects/launch_binding', params: { launch_token: token, project: project },
                                                 headers: headers, as: :json
      end
      assert_response :unprocessable_content
    end
  end

  test 'a copy that becomes missing or belongs to another record cannot be used' do
    token = ticket
    @asset.update!(status: 'missing')
    assert_raises(ArgumentError) do
      EncoderProjects::LaunchTicket.read(token, user: @user, url: @configuration['url'])
    end
    another = Record.create!(french_title: 'Autre', record_kind: 'standalone_video',
                              language_version: @record.language_version)
    @asset = VideoAsset.create!(record: another, status: 'present', last_known_path: '/videos/Autre.mkv')
    assert_raises(ActiveRecord::RecordNotFound) { ticket }
  end

  test 'reusing a copy link can prepare independent projects while retaining the signed record and source scope' do
    token = ticket
    headers = { 'Authorization' => "Bearer #{@configuration['token']}" }
    EncoderProjects::Settings.stub(:read, @configuration) do
      2.times do
        project = { 'project_id' => SecureRandom.uuid, 'project_path' => '/videos/new.json',
                    'output_path' => '/videos/new.mkv', 'source_paths' => [@asset.last_known_path] }
        binder = lambda do |data:, launch:, user:, url:|
          assert_equal project['project_id'], launch['project_id']
          assert_equal @record.id, launch['record_id']
          assert_equal @asset.id, launch.dig('source_copy', 'id')
          assert_equal project, data
          assert_equal @user, user
          assert_equal @configuration['url'], url
          { status: 'identified' }
        end
        EncoderProjects::LaunchBinding.stub(:call, binder) do
          post '/encoder_projects/launch_binding', params: { launch_token: token, project: project },
                                                   headers: headers, as: :json
        end
        assert_response :success
      end
    end
  end

  test 'the record page offers the action on a present MKV without changing the record language' do
    sign_in @user
    get record_path(@record)
    assert_select "a[href='#{encoder_copy_version_path(@record, @asset)}']", text: 'Changer de version…'
    assert_equal 'VM', @record.reload.language_version.short_name
    @asset.update!(status: 'missing')
    get record_path(@record)
    assert_select "a[href='#{encoder_copy_version_path(@record, @asset)}']", count: 0
  end
end
