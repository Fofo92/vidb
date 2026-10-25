require 'test_helper'

class EncoderEpisodeDestinationTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test 'an explicitly selected episode binds a provisional destination and exposes its hierarchy' do
    user = User.create!(email: 'episode-destination@example.com', password: 'password')
    language = LanguageVersion.find_or_create_by!(short_name: 'IND') { |item| item.long_name = 'Indéterminée' }
    root = Record.create!(french_title: "Cat's Eyes", record_kind: 'series', language_version: language)
    project = { 'project_id' => SecureRandom.uuid, 'project_path' => '/videos/montage.json',
                'output_path' => '/videos/montage.mkv',
                'source_paths' => ["/commun/to_be_cut/Cat's Eyes - S02 E01 - Un nouvel espoir.m2t"] }
    token = EncoderProjects::CatalogueScope.issue(user: user, project: project)
    sign_in user
    assert_no_difference('VideoAsset.count') do
      post encoder_projects_episode_path, params: { request_token: token, series_id: root.id,
                                                   title: 'Un nouvel espoir', year: '2026' }
    end
    episode = root.descendants.find_by!(record_kind: 'episode')
    assert_redirected_to record_path(episode)
    assert_equal episode.id, EncoderProjects::Binding.current(project['project_id']).fetch('record_id')
    metadata = EncoderProjects::RecordPresentation.call(episode)
    assert_equal ["Cat's Eyes"], metadata.fetch('series_titles')
    assert_equal 2, metadata.fetch('season_number')
    assert_equal 1, metadata.fetch('episode_number')
    assert_no_difference('Record.count') do
      post encoder_projects_episode_path, params: { request_token: token, series_id: root.id,
                                                   title: 'Un nouvel espoir', year: '2026' }
    end
  end
end
