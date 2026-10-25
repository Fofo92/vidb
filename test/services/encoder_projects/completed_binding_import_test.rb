require 'test_helper'
require 'minitest/mock'
require 'tmpdir'

class EncoderProjects::CompletedBindingImportTest < ActiveSupport::TestCase
  setup do
    @directory = Dir.mktmpdir
    @path = File.join(@directory, 'Nom final indépendant.mkv')
    File.write(@path, 'video')
    language = LanguageVersion.create!(short_name: 'VF', long_name: 'Français')
    Medium.create!(short_name: 'HD', long_name: 'Disque dur')
    @record = Record.create!(french_title: 'Œuvre validée', record_kind: 'standalone_video', language_version: language)
    @other = Record.create!(french_title: 'Autre œuvre', record_kind: 'standalone_video', language_version: language)
    uuid = '4d013c0a-7b54-4a67-aef2-7e1af7f6d410'
    @receipt = { 'project_id' => uuid, 'vidb' => EncoderProjects::Binding.issue(uuid, @record),
      'format' => 'video_encoder.completed_export', 'version' => 1, 'output_path' => @path,
      'roles' => ['french'], 'byte_size' => 5, 'project_sha256' => 'a' * 64,
      'completed_at' => Time.current.utc.iso8601(6), 'modified_at' => File.mtime(@path).utc.iso8601(6) }
    @details = { 'streams' => [{ 'index' => 0, 'codec_type' => 'video', 'codec_name' => 'h264' },
      { 'index' => 1, 'codec_type' => 'audio', 'codec_name' => 'aac', 'tags' => { 'language' => 'fra' } }],
      'format' => { 'duration' => '2400', 'format_name' => 'matroska' } }
    @receipt['probe'] = @details
    stat = File.stat(@path)
    @export = { receipt: @receipt, details: @details, seconds: 2400, signature: [stat.size, stat.mtime, stat.ino] }
    File.write("#{@path}#{VideoAssets::CompletedExport::SUFFIX}", '{}')
  end

  teardown { FileUtils.remove_entry(@directory) }

  def import(observation)
    value = @export
    reader = Object.new
    reader.define_singleton_method(:call) { value }
    VideoAssets::CompletedExport.stub(:new, ->(_path) { reader }) do
      VideoAssets::CompletedExports.new.call(observations: [observation.merge(path: @path)]).sole
    end
  end

  test 'validated binding attaches the real final file instead of a conflicting filename candidate' do
    result = import(status: 'ambiguous_exact', candidates: [{ record_id: @other.id }])
    assert_equal 'imported', result[:status], result[:reason]
    assert_equal @record.id, VideoAsset.sole.record_id
    assert_equal @path, VideoAsset.sole.last_known_path
    assert_equal 0, @other.video_assets.count
    assert_equal 'already_imported', import(status: 'unmatched', candidates: [])[:status]
    assert_equal 1, VideoAsset.count
  end

  test 'an invalid signature cannot fall back to a plausible filename match' do
    @receipt['vidb']['binding_token'] = 'forged'
    result = import(status: 'episode_candidate', title_evidence: 'title_match', candidates: [{ record_id: @other.id }])
    assert_equal 'needs_review', result[:status]
    assert_equal 0, VideoAsset.count
  end

  test 'a file changed after inspection is never attached' do
    File.write(@path, 'replaced')
    result = import(status: 'unmatched', candidates: [])
    assert_equal 'needs_review', result[:status]
    assert_equal 0, VideoAsset.count
  end
end
