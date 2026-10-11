# frozen_string_literal: true

require 'test_helper'
require 'tmpdir'
require 'json'

class CompletedExportImportTest < ActiveSupport::TestCase
  setup do
    @directory = Dir.mktmpdir
    @path = File.join(@directory, 'S05 E01 - Panique.mkv')
    File.write(@path, 'video')
    vf = LanguageVersion.find_or_create_by!(short_name: 'VF') { |v| v.long_name = 'Français' }
    Medium.find_or_create_by!(short_name: 'HD') { |m| m.long_name = 'Disque dur' }
    root = Record.create!(french_title: '9-1-1', record_kind: 'series', language_version: vf)
    season = Record.create!(french_title: 'Saison 05', parent: root, rank: 5,
                            record_kind: 'season', language_version: vf)
    @record = Record.create!(french_title: 'Panique', original_title: 'Panic', parent: season, rank: 1,
                             record_kind: 'episode', language_version: vf, is_seen: true, abstract: 'Conservé')
    @observation = { path: @path, status: 'episode_candidate', title_evidence: 'title_match',
                     candidates: [@record.attributes.symbolize_keys.slice(:french_title, :original_title, :rank, :ancestry)
                                        .merge(record_id: @record.id)] }
    stat = File.stat(@path)
    @receipt = { 'format' => 'video_encoder.completed_export', 'version' => 1, 'output_path' => @path,
                 'project_sha256' => 'a' * 64, 'roles' => ['french'], 'byte_size' => stat.size,
                 'modified_at' => stat.mtime.utc.iso8601(6) }
    @details = { 'streams' => [{ 'index' => 0, 'codec_type' => 'video', 'codec_name' => 'h264' },
                               { 'index' => 1, 'codec_type' => 'audio', 'tags' => { 'language' => 'fra' } }],
                 'format' => { 'duration' => '2400', 'format_name' => 'matroska' } }
    @receipt['probe'] = @details
    @export = { receipt: @receipt, details: @details, seconds: 2400, signature: [stat.size, stat.mtime, stat.ino] }
  end

  teardown do
    FileUtils.remove_entry(@directory)
  end

  test 'imports another copy and fills duration without changing seen or abstract' do
    VideoAsset.create!(record: @record, status: 'present', last_known_path: "#{@path}_vf")
    assert_difference 'VideoAsset.count', 1 do
      assert_equal 'imported', VideoAssets::CompletedExportImport.new(@observation, @export).call[:status]
    end
    assert_equal 40, @record.reload.length_in_mn
    assert_equal true, @record.is_seen
    assert_equal 'Conservé', @record.abstract
    asset = VideoAsset.find_by!(last_known_path: @path)
    assert_equal 'HD', asset.medium.short_name
    assert_equal 'VF', asset.language_version.short_name
  end

  test 'replaying the same receipt is idempotent' do
    VideoAssets::CompletedExportImport.new(@observation, @export).call
    assert_no_difference 'VideoAsset.count' do
      assert_equal 'already_imported', VideoAssets::CompletedExportImport.new(@observation, @export).call[:status]
    end
  end

  test 'changed file prevents all writes' do
    File.write(@path, 'replacement')
    assert_no_difference 'VideoAsset.count' do
      assert_raises(ArgumentError) { VideoAssets::CompletedExportImport.new(@observation, @export).call }
    end
    assert_nil @record.reload.length_in_mn
  end

  test 'changed placement prevents all writes' do
    @record.update!(rank: 2)
    assert_raises(ArgumentError) { VideoAssets::CompletedExportImport.new(@observation, @export).call }
  end

  test 'existing path with a different receipt preserves history' do
    VideoAsset.create!(record: @record, status: 'deleted', last_known_path: @path)
    assert_no_difference 'VideoAsset.count' do
      assert_raises(ArgumentError) { VideoAssets::CompletedExportImport.new(@observation, @export).call }
    end
  end

  test 'missing target is reserved and never creates a record' do
    File.write("#{@path}#{VideoAssets::CompletedExport::SUFFIX}", JSON.generate(@receipt))
    observation = @observation.merge(status: 'deferred_episode', candidates: [])
    assert_no_difference ['Record.count', 'VideoAsset.count'] do
      result = VideoAssets::CompletedExports.new.call(observations: [observation])
      assert_equal 'needs_review', result.sole[:status]
    end
  end

  test 'receipt requires current final streams and matching file metadata' do
    File.write("#{@path}#{VideoAssets::CompletedExport::SUFFIX}", JSON.generate(@receipt))
    reader = VideoAssets::CompletedExport.new(@path)
    reader.define_singleton_method(:probe) { @test_details }
    reader.instance_variable_set(:@test_details, @details)
    assert_equal 2400, reader.call[:seconds]
    reader.instance_variable_set(:@test_details, @details.merge('streams' => []))
    assert_raises(ArgumentError) { reader.call }
  end

  test 'unchanged imported receipts do not repeat ffprobe on every scan' do
    File.write("#{@path}#{VideoAssets::CompletedExport::SUFFIX}", JSON.generate(@receipt))
    VideoAssets::CompletedExportImport.new(@observation, @export).call
    reader = VideoAssets::CompletedExport.new(@path)
    reader.define_singleton_method(:probe) { raise 'ffprobe must not run again' }
    assert_equal 2400, reader.call[:seconds]
  end

  test 'multiple target candidates remain reserved' do
    File.write("#{@path}#{VideoAssets::CompletedExport::SUFFIX}", JSON.generate(@receipt))
    observation = @observation.merge(candidates: @observation[:candidates] * 2)
    assert_no_difference 'VideoAsset.count' do
      assert_equal 'needs_review', VideoAssets::CompletedExports.new.call(observations: [observation]).sole[:status]
    end
  end

  test 'missing receipt never imports a matching video' do
    assert_no_difference 'VideoAsset.count' do
      assert_empty VideoAssets::CompletedExports.new.call(observations: [@observation])
    end
  end
end
