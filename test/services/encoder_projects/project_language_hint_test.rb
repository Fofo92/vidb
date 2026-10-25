require 'test_helper'

class EncoderProjects::ProjectLanguageHintTest < ActiveSupport::TestCase
  def project
    { 'project_id' => '4d013c0a-7b54-4a67-aef2-7e1af7f6d410', 'project_path' => '/videos/montage.json',
      'output_path' => '/videos/montage.mkv', 'source_paths' => ['/commun/source.m2t'] }
  end

  test 'language is optional for projects saved with earlier versions' do
    assert_equal project, EncoderProjects::ProjectRequest.new(project).data
  end

  test 'keeps only a recognized language hint for the signed review' do
    data = EncoderProjects::ProjectRequest.new(project.merge('language_hint' => 'VF', 'is_available' => true)).data
    assert_equal 'VF', data['language_hint']
    refute data.key?('is_available')
    assert_raises(ArgumentError) { EncoderProjects::ProjectRequest.new(project.merge('language_hint' => 'unsupported')) }
  end
end
