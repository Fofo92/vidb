require 'test_helper'
require 'minitest/mock'

class EncoderProjectCompletionRedirectTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(email: 'encoder-completion@example.com', password: 'password')
    language = LanguageVersion.find_or_create_by!(short_name: 'IND') { |row| row.long_name = 'Indéterminée' }
    @record = Record.create!(french_title: 'Film de test', record_kind: 'standalone_video', language_version: language)
    project = { 'project_id' => SecureRandom.uuid, 'project_path' => '/videos/test.json',
                'output_path' => '/videos/test.mkv', 'source_paths' => ['/commun/to_be_cut/test.m2t'] }
    @token = EncoderProjects::CatalogueScope.issue(user: @user, project: project)
    sign_in @user
  end

  def prepared_service
    record = @record
    Object.new.tap { |service| service.define_singleton_method(:call) { |**_parameters| record } }
  end

  test 'film and episode confirmations signal successful preparation only for the embedded form' do
    [[EncoderProjects::CatalogueCreation, encoder_projects_catalogue_path],
     [EncoderProjects::EpisodePreparation, encoder_projects_episode_path]].each do |service, path|
      service.stub(:new, ->(**_options) { prepared_service }) do
        post path, params: { request_token: @token, encoder_window: '1' }
        assert_redirected_to record_path(@record, encoder_prepared: 1)
        post path, params: { request_token: @token }
        assert_redirected_to record_path(@record)
      end
    end
  end

  test 'an invalid scope never produces a successful preparation redirect' do
    post encoder_projects_episode_path, params: { request_token: 'invalid', encoder_window: '1' }
    assert_response :unprocessable_content
  end
end
