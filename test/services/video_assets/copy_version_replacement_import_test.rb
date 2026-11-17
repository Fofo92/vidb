require 'test_helper'
require 'tmpdir'
require 'digest'
require 'json'

class CopyVersionReplacementImportTest < ActiveSupport::TestCase
  setup do
    @folder = Dir.mktmpdir
    @target = File.join(@folder, 'Film.mkv')
    @previous = File.join(@folder, 'Film - VOST.mkv')
    @archive = File.join(@folder, '.video_encoder_trash', 'version-test')
    FileUtils.mkdir_p(@archive)
    @archived = File.join(@archive, '1-Film.mkv')
    @old_project = File.join(@archive, '0-Film.json')
    File.binwrite(@archived, 'old source audio fra and qaa')
    File.write(@old_project, '{"format":"video_encoder.trim_project","version":2}')
    File.write(File.join(@archive, 'manifest.json'), JSON.generate(
      File.join(@folder, 'Film.json') => @old_project, @target => @archived
    ))
    File.binwrite(@target, 'converted VOST')
    vm = LanguageVersion.find_or_create_by!(short_name: 'VM') { |v| v.long_name = 'Multilingue' }
    vost = LanguageVersion.find_or_create_by!(short_name: 'VOST') { |v| v.long_name = 'Originale sous-titrée' }
    Medium.find_or_create_by!(short_name: 'HD') { |m| m.long_name = 'Disque dur' }
    @record = Record.create!(french_title: 'Film', record_kind: 'standalone_video', language_version: vm,
                             is_seen: true, length_in_mn: 89)
    @source = VideoAsset.create!(record: @record, status: 'present', last_known_path: @target,
                                 byte_size: File.size(@archived), language_version: vm)
    details = { 'streams' => [{ 'index' => 0, 'codec_type' => 'video', 'codec_name' => 'hevc' },
                              { 'index' => 1, 'codec_type' => 'audio', 'codec_name' => 'aac',
                                'tags' => { 'language' => 'qaa' } }],
                'format' => { 'filename' => @previous, 'duration' => '5340', 'format_name' => 'matroska' } }
    stat = File.stat(@target)
    identity = VideoAssets::CopyVersionReplacementImport.allocate.send(:signature, @archived)
    old_receipt = { 'format' => 'video_encoder.completed_export', 'version' => 1,
                    'project_id' => 'same-project', 'project_path' => @previous.sub(/\.mkv\z/, '.json'),
                    'output_path' => @previous, 'project_sha256' => 'a' * 64, 'roles' => ['original'],
                    'byte_size' => stat.size, 'modified_at' => stat.mtime.utc.iso8601(6),
                    'version_change' => { 'source_path' => @target, 'identity' => identity, 'profile' => 'VOST',
                                         'original_confirmed' => true, 'burned_french_confirmed' => true },
                    'probe' => details }
    @converted = VideoAsset.create!(record: @record, status: 'present', last_known_path: @previous,
                                    byte_size: stat.size, language_version: vost,
                                    technical_details: details.merge('video_encoder_export' => old_receipt))
    @receipt = old_receipt.deep_dup
    @receipt.merge!('project_path' => @target.sub(/\.mkv\z/, '.json'), 'output_path' => @target,
                    'previous_output_path' => @previous, 'project_sha256' => 'b' * 64)
    @receipt['version_change']['source_path'] = @archived
    @receipt['probe']['format']['filename'] = @target
    @receipt['copy_version_replacement'] = {
      'source_path' => @target, 'archived_source_path' => @archived, 'archive_directory' => @archive,
      'archived_project_path' => @old_project, 'source_project_sha256' => Digest::SHA256.file(@old_project).hexdigest,
      'source_identity' => identity, 'source_missing_before_replacement' => false, 'replaced_at' => Time.current.iso8601
    }
    @observation = { path: @target, candidates: [@record.attributes.symbolize_keys
      .slice(:ancestry, :rank, :french_title, :original_title).merge(record_id: @record.id)] }
    @export = { receipt: @receipt, details: @receipt['probe'], seconds: 5340,
                signature: [stat.size, stat.mtime, stat.ino] }
  end

  teardown do
    FileUtils.remove_entry(@folder)
  end

  def import
    VideoAssets::CompletedExportImport.new(@observation, @export).call
  end

  test 'replacement archives the VM reference and relocates the existing VOST without creating duplicates' do
    before = @record.attributes
    assert_no_difference 'VideoAsset.count' do
      assert_equal 'relocated', import[:status]
    end
    assert_equal @archived, @source.reload.last_known_path
    assert_equal 'deleted', @source.status
    assert_equal 'VM', @source.language_version.short_name
    assert_equal @archive, @source.technical_details.dig('copy_removal', 'directory')
    assert_equal @target, @converted.reload.last_known_path
    assert_equal 'present', @converted.status
    assert_equal 'VOST', @converted.language_version.short_name
    assert_equal @receipt, @converted.technical_details['video_encoder_export']
    assert_equal before, @record.reload.attributes
  end

  test 'a repeated inventory remains idempotent even after the recovery archive expires' do
    import
    FileUtils.remove_entry(@archive)
    assert_no_difference 'VideoAsset.count' do
      assert_equal 'already_imported', import[:status]
    end
  end

  test 'an unverified archive cannot release an existing copy reference' do
    File.write(@old_project, 'modified')
    assert_raises(ArgumentError) { import }
    assert_equal @target, @source.reload.last_known_path
    assert_equal 'present', @source.status
    assert_equal @previous, @converted.reload.last_known_path
  end

  test 'a different source file rolls back the complete import' do
    File.write(@archived, 'different source')
    assert_raises(ArgumentError) { import }
    assert_equal @target, @source.reload.last_known_path
    assert_equal @previous, @converted.reload.last_known_path
  end

  test 'a source already absent before replacement remains historical and is not confused with the VOST' do
    File.unlink(@archived)
    @receipt['copy_version_replacement']['source_missing_before_replacement'] = true
    assert_equal 'relocated', import[:status]
    assert_equal 'deleted', @source.reload.status
    assert_equal @target, @converted.reload.last_known_path
  end

  def missing_project_with_receipt
    change = @receipt['copy_version_replacement']
    identity = change['source_identity']
    modified = Time.at(Rational(identity['mtime_ns'], 1_000_000_000)).utc.iso8601(6)
    previous_receipt = {
      'format' => 'video_encoder.completed_export', 'version' => 1,
      'project_path' => @target.sub(/\.mkv\z/, '.json'), 'output_path' => @target,
      'project_sha256' => change['source_project_sha256'], 'byte_size' => identity['size'],
      'modified_at' => modified, 'vidb' => { 'record_id' => @record.id }
    }
    suffix = '.video_encoder-export.json'
    path = @archived + suffix
    File.write(path, JSON.generate(previous_receipt))
    File.unlink(@old_project)
    change['source_project_missing_before_replacement'] = true
    File.write(File.join(@archive, 'manifest.json'), JSON.generate(@target => @archived, @target + suffix => path))
    path
  end

  test 'a missing original JSON is supported with its verified archived video and export receipt' do
    path = missing_project_with_receipt
    before = File.binread(@archived)
    assert_no_difference 'VideoAsset.count' do
      assert_equal 'relocated', import[:status]
    end
    assert_equal 'deleted', @source.reload.status
    assert_equal @target, @converted.reload.last_known_path
    assert_equal before, File.binread(@archived)
    assert File.file?(path)
    assert_not File.exist?(@old_project)
  end

  test 'a missing original JSON requires an archived receipt belonging to the same record' do
    path = missing_project_with_receipt
    original = JSON.parse(File.read(path))
    [{ 'vidb' => { 'record_id' => @record.id + 1 } }, { 'project_sha256' => 'f' * 64 },
     { 'byte_size' => 0 }, { 'modified_at' => '2000-01-01T00:00:00Z' }].each do |change|
      File.write(path, JSON.generate(original.merge(change)))
      assert_raises(ArgumentError) { import }
      assert_equal @target, @source.reload.last_known_path
      assert_equal @previous, @converted.reload.last_known_path
    end
  end

  test 'a missing original JSON cannot be justified by a missing old receipt or missing video' do
    path = missing_project_with_receipt
    bytes = File.binread(path)
    File.unlink(path)
    assert_raises(ArgumentError) { import }
    File.binwrite(path, bytes)
    File.unlink(@archived)
    @receipt['copy_version_replacement']['source_missing_before_replacement'] = true
    assert_raises(ArgumentError) { import }
    assert_equal @target, @source.reload.last_known_path
  end
end
