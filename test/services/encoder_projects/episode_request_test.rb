require 'test_helper'

class EncoderProjects::EpisodeRequestTest < ActiveSupport::TestCase
  test 'recognizes an episode in the source before the destination is named' do
    episode = EncoderProjects::EpisodeRequest.new(
      'source_paths' => ["/commun/to_be_cut/Cat's Eyes - S02 E01 - Un nouvel espoir.m2t"],
      'output_path' => '/videos/montage.mkv'
    )
    assert_equal "Cat's Eyes", episode.series
    assert_equal 2, episode.season
    assert_equal 1, episode.episode
    assert_equal 'Un nouvel espoir', episode.title
  end

  test 'recognizes a numbered destination without a source' do
    episode = EncoderProjects::EpisodeRequest.new('output_path' => '/videos/S04 E17 - Suite.mkv')
    assert_equal 17, episode.episode
    assert_equal 'Suite', episode.title
  end

  test 'films and episode zero do not enter the episode workflow' do
    refute EncoderProjects::EpisodeRequest.match?('output_path' => '/videos/Adieu Philippine.mkv')
    refute EncoderProjects::EpisodeRequest.match?('output_path' => '/videos/S02 E00 - Invalide.mkv')
  end
end
