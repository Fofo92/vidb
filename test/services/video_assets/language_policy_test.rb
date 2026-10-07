# frozen_string_literal: true

require 'test_helper'
require 'tmpdir'
require 'json'

class LanguagePolicyTest < ActiveSupport::TestCase
  setup do
    @directory = Dir.mktmpdir('vidb-language-policy')
    version = LanguageVersion.create!(short_name: 'POLICY', long_name: 'Test politique')
    record = Record.create!(french_title: 'Politique langues', language_version: version,
                            record_kind: 'standalone_video')
    @asset = VideoAsset.create!(record: record, last_known_path: "#{@directory}/episode.mkv")
    @old = 3.days.ago.to_time
  end

  teardown do
    FileUtils.remove_entry(@directory)
  end

  test 'encoder convention proposes VMST from final roles without inventing English' do
    prepare_copy('fra', 'qaa', subtitles: true)
    prepare_project
    report = proposal
    assert_equal 'VMST', report[:suggested_version]
    assert_equal 'matched', report.dig(:encoder_evidence, :status)
    assert_equal %w[fra qaa], report[:declared_audio_languages]
    assert_nil @asset.reload.language_version_id
  end

  test 'encoder convention distinguishes VM VO and VOST' do
    prepare_project
    prepare_copy('fra', 'qaa')
    assert_equal 'VM', proposal[:suggested_version]
    prepare_copy('qaa')
    assert_equal 'VO', proposal[:suggested_version]
    prepare_copy('qaa', subtitles: true)
    assert_equal 'VOST', proposal[:suggested_version]
  end

  test 'qaa without companion project remains under review' do
    prepare_copy('fra', 'qaa', subtitles: true)
    assert_equal 'needs_review', proposal[:status]
  end

  test 'French filename qualifies a single unlabelled track' do
    @asset.update!(last_known_path: "#{@directory}/episode_vf.mkv")
    prepare_copy(nil)
    assert_equal 'VF', proposal[:suggested_version]
  end

  test 'French filename cannot override foreign audio or an encoder conflict' do
    @asset.update!(last_known_path: "#{@directory}/episode_vf.mkv")
    prepare_copy('eng')
    assert_equal 'needs_review', proposal[:status]
    prepare_copy('fra', 'qaa', subtitles: true)
    prepare_project
    assert_equal 'needs_review', proposal[:status]
    assert_nil proposal[:suggested_version]
  end

  test 'forced subtitles alone do not imply VMST' do
    prepare_copy('fra', 'qaa', subtitles: true)
    details = @asset.technical_details.deep_dup
    details['streams'].last['disposition'] = { 'forced' => 1 }
    @asset.update!(technical_details: details)
    prepare_project
    assert_equal 'VM', proposal[:suggested_version]
  end

  test 'a recently modified or resized copy stays under review' do
    prepare_copy('fra', 'qaa')
    prepare_project
    File.utime(Time.current.to_time, Time.current.to_time, @asset.last_known_path)
    assert_equal 'copy_not_stable', proposal.dig(:encoder_evidence, :status)
    File.utime(@old, @old, @asset.last_known_path)
    File.write(@asset.last_known_path, 'changed')
    assert_equal 'needs_review', proposal[:status]
  end

  test 'a project without its final copy does not qualify availability' do
    prepare_project
    assert_equal 'needs_review', proposal[:status]
    assert_equal 'copy_not_stable', proposal.dig(:encoder_evidence, :status)
    assert_nil @asset.reload.language_version_id
  end

  test 'incomplete original role across used sources prevents interpreting qaa' do
    prepare_copy('fra', 'qaa')
    document = project_document
    document['sources'] << { 'id' => 'second', 'inspection' => { 'audio_tracks' => [{ 'language' => 'fra' }] } }
    document['timeline'] << { 'type' => 'segment', 'source_id' => 'second' }
    prepare_project(document)
    assert_equal 'needs_review', proposal[:status]
  end

  test 'unused sources do not suppress an original role' do
    prepare_copy('fra', 'qaa')
    document = project_document
    document['sources'] << { 'id' => 'unused', 'inspection' => { 'audio_tracks' => [] } }
    prepare_project(document)
    assert_equal 'VM', proposal[:suggested_version]
  end

  test 'invalid project is reported without stopping the batch' do
    prepare_copy('fra', 'qaa')
    prepare_project({ 'format' => 'video_encoder.trim_project', 'version' => 2, 'sources' => [nil], 'timeline' => [] })
    assert_equal 'unreadable', proposal.dig(:encoder_evidence, :status)
    assert_equal 'needs_review', proposal[:status]
  end

  test 'new project cannot qualify an older export' do
    prepare_copy('fra', 'qaa')
    prepare_project
    path = Pathname.new(@asset.last_known_path).sub_ext('.json')
    File.utime(Time.current.to_time, Time.current.to_time, path)
    assert_equal 'copy_not_stable', proposal.dig(:encoder_evidence, :status)
    assert_nil proposal[:suggested_version]
  end

  private

  def proposal
    VideoAssets::LanguageProposal.new(@asset).call
  end

  def prepare_copy(*languages, subtitles: false)
    File.write(@asset.last_known_path, 'copy')
    File.utime(@old, @old, @asset.last_known_path)
    streams = languages.map { |value| { 'codec_type' => 'audio', 'tags' => { 'language' => value } } }
    streams << { 'codec_type' => 'subtitle', 'tags' => { 'language' => 'fra' } } if subtitles
    @asset.update!(byte_size: 4, technical_details: { 'streams' => streams, 'observed_at' => Time.current.iso8601 })
  end

  def prepare_project(document = project_document)
    path = Pathname.new(@asset.last_known_path).sub_ext('.json')
    path.write(JSON.generate(document))
    File.utime(@old - 60, @old - 60, path)
  end

  def project_document
    {
      'format' => 'video_encoder.trim_project', 'version' => 2,
      'sources' => [{ 'id' => 'source', 'inspection' => { 'audio_tracks' => [
        { 'language' => 'fra' }, { 'language' => 'fra', 'visual_impaired' => true }, { 'language' => 'qaa' }
      ] } }],
      'timeline' => [{ 'type' => 'segment', 'source_id' => 'source' }]
    }
  end
end
