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
    assert_select 'select[name="series_id"] option', text: /Cat's Eyes/
  end

  test 'confirmation creates the hierarchy without a video file' do
    assert_difference('Record.count', 2) do
      assert_no_difference('VideoAsset.count') do
        post encoder_projects_episode_path, params: { request_token: @token, series_id: @series.id,
                                                     title: 'Un nouvel espoir', year: '2026' }
      end
    end
    episode = @series.descendants.find_by!(record_kind: 'episode')
    assert_redirected_to record_path(episode)
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
end
