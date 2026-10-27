require 'test_helper'

module EncoderProjects
  class EpisodeTargetTest < ActiveSupport::TestCase
    def project
      { 'source_paths' => ['/commun/Fifteen Love - S01 E01.m2t'], 'output_path' => '/videos/source.mkv' }
    end

    test 'an explicit target takes priority over the shared source number' do
      request = EncoderProjects::EpisodeRequest.new(project.merge('episode_target' => { 'season' => 1,
                                                                                        'episode' => 2 }))
      assert_equal 1, request.season
      assert_equal 2, request.episode
      assert_equal '', request.title
      assert_equal 'Fifteen Love', request.series
    end

    test 'invalid target is rejected rather than falling back to the source episode' do
      assert_raises(ArgumentError) do
        EncoderProjects::EpisodeRequest.new(project.merge('episode_target' => { 'season' => 1, 'episode' => 0 }))
      end
    end
  end
end
