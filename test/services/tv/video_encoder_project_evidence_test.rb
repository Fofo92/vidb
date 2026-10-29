require 'test_helper'
require 'tmpdir'
require 'json'
require 'minitest/mock'

class Tv::VideoEncoderProjectEvidenceTest < ActiveSupport::TestCase
  Asset = Struct.new(:last_known_path, :record_id, :technical_details)

  def project
    { 'format' => 'video_encoder.trim_project', 'version' => 2, 'project_id' => 'project-42',
      'sources' => [{ 'id' => 'source', 'path' => '/absent/quarantined-source.m2t' }],
      'timeline' => [{ 'type' => 'segment', 'source_id' => 'source', 'start_frame' => 0, 'end_frame' => 100 }] }
  end

  test 'a matching project beside a video identifies video_encoder even without a receipt' do
    Dir.mktmpdir do |directory|
      video = File.join(directory, 'Film français.mkv')
      File.write(File.join(directory, 'Film français.json'), JSON.generate(project))
      asset = Asset.new(video, 42, { 'streams' => [{ 'codec_type' => 'audio', 'tags' => { 'language' => 'fra' } }] })
      assert_equal :associated, Tv::VideoEncoderProjectEvidence.new.call(asset)
      asset.technical_details['streams'] = []
      assert_equal :associated, Tv::VideoEncoderProjectEvidence.new.call(asset)
    end
  end

  test 'a receipt can identify a project with a different name or directory' do
    Dir.mktmpdir do |directory|
      video = File.join(directory, 'output.mkv')
      path = File.join(directory, 'cutting-project.json')
      File.write(path, JSON.generate(project))
      receipt = { 'output_path' => video, 'project_path' => path, 'project_id' => 'project-42' }
      asset = Asset.new(video, 42, { 'video_encoder_export' => receipt })
      assert_equal :associated, Tv::VideoEncoderProjectEvidence.new.call(asset)
      receipt['project_id'] = 'another-project'
      assert_equal :unknown, Tv::VideoEncoderProjectEvidence.new.call(asset)
      receipt['output_path'] = '/other/output.mkv'
      assert_equal :absent, Tv::VideoEncoderProjectEvidence.new.call(asset)
    end
  end

  test 'an old copy without a project remains a replacement candidate whatever its audio' do
    Dir.mktmpdir do |directory|
      %w[fra eng].each do |language|
        asset = Asset.new(File.join(directory, 'old.m4v'), 42,
                          { 'streams' => [{ 'codec_type' => 'audio', 'tags' => { 'language' => language } }] })
        assert_equal :absent, Tv::VideoEncoderProjectEvidence.new.call(asset)
      end
      File.write(File.join(directory, 'old.json'), JSON.generate('unrelated' => true))
      assert_equal :absent, Tv::VideoEncoderProjectEvidence.new.call(Asset.new(File.join(directory, 'old.m4v'), 42, {}))
    end
  end

  test 'malformed projects and conflicting vidb bindings require review' do
    Dir.mktmpdir do |directory|
      path = File.join(directory, 'movie.json')
      asset = Asset.new(File.join(directory, 'movie.mkv'), 42, {})
      File.write(path, '{broken')
      assert_equal :unknown, Tv::VideoEncoderProjectEvidence.new.call(asset)
      File.write(path, JSON.generate(project.merge('vidb' => { 'record_id' => 43 })))
      assert_equal :unknown, Tv::VideoEncoderProjectEvidence.new.call(asset)
      File.write(path, 'x' * (Tv::VideoEncoderProjectEvidence::MAX_BYTES + 1))
      assert_equal :unknown, Tv::VideoEncoderProjectEvidence.new.call(asset)
    end
  end

  test 'an export receipt alone does not replace a missing project' do
    asset = Asset.new('/absent/movie.mkv', 42,
                      { 'video_encoder_export' => { 'output_path' => '/absent/movie.mkv',
                                                    'project_path' => '/absent/movie.json' } })
    assert_equal :absent, Tv::VideoEncoderProjectEvidence.new.call(asset)
  end
end
