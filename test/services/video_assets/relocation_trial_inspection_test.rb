# frozen_string_literal: true

require 'test_helper'
require 'tmpdir'
require 'fileutils'
require 'json'

class RelocationTrialInspectionTest < ActiveSupport::TestCase
  setup do
    @root = Dir.mktmpdir('vidb-relocation-', '/tmp')
    @source = File.join(@root, 'ancien.mkv')
    @target = File.join(@root, 'nouveau.mkv')
    @journal = File.join(@root, 'relocation-test.jsonl')
    File.binwrite(@source, 'fake mkv data')
    language = LanguageVersion.create!(short_name: 'VF', long_name: 'Version française')
    @record = Record.create!(french_title: 'Film de test', language_version: language)
    @asset = VideoAsset.create!(record: @record, last_known_path: @source, byte_size: File.size(@source))
    stat = File.stat(@source)
    @prepared = {
      'event' => 'prepared', 'at' => Time.now.utc.iso8601(6),
      'asset_id' => @asset.id, 'record_id' => @record.id,
      'source' => @source, 'target' => @target,
      'identity' => { 'dev' => stat.dev, 'ino' => stat.ino, 'size' => stat.size,
                      'mtime_ns' => (stat.mtime.to_r * 1_000_000_000).to_i,
                      'ctime_ns' => (stat.ctime.to_r * 1_000_000_000).to_i }
    }
    write_events(@prepared)
  end

  teardown do
    FileUtils.remove_entry(@root) if @root && File.directory?(@root)
  end

  test 'recognizes an unchanged source with the database still pointing to it' do
    result = inspect_trial
    assert_equal :consistent_source, result[:status]
    assert_equal false, result[:automatic_action]
  end

  test 'detects a rename interrupted before the database update' do
    File.rename(@source, @target)
    write_events(@prepared, event('filesystem_renamed'), event('needs_review'))
    result = inspect_trial
    assert_equal :database_update_pending, result[:status]
    assert_equal @source, result[:database][:path]
    assert_equal false, result[:automatic_action]
  end

  test 'detects a rename even when the journal lacks the filesystem event' do
    File.rename(@source, @target)
    assert_equal :database_update_pending, inspect_trial[:status]
  end

  test 'recognizes a consistent target after the database update' do
    File.rename(@source, @target)
    @asset.update!(last_known_path: @target)
    write_events(@prepared, event('filesystem_renamed'), event('completed'))
    assert_equal :consistent_target, inspect_trial[:status]
  end

  test 'diagnoses actual state even if the completion event was not written' do
    File.rename(@source, @target)
    @asset.update!(last_known_path: @target)
    write_events(@prepared, event('filesystem_renamed'), event('needs_review'))
    assert_equal :consistent_target, inspect_trial[:status]
  end

  test 'reports a conflict if both paths are present' do
    File.binwrite(@target, 'existing destination')
    assert_equal :conflict, inspect_trial[:status]
  end

  test 'reports a conflict if neither path is present' do
    File.unlink(@source)
    assert_equal :conflict, inspect_trial[:status]
  end

  test 'does not mistake a different inode of the same size for the renamed file' do
    File.binwrite(@target, 'X' * @asset.byte_size)
    time = File.mtime(@source)
    File.utime(time, time, @target)
    File.unlink(@source)
    assert_equal :conflict, inspect_trial[:status]
  end

  test 'does not follow a symbolic source' do
    File.rename(@source, @target)
    File.symlink(@target, @source)
    result = inspect_trial
    assert_equal :conflict, result[:status]
    assert_equal :symlink, result[:source][:state]
  end

  test 'rejects a symbolic journal' do
    actual = File.join(@root, 'actual.jsonl')
    File.rename(@journal, actual)
    File.symlink(actual, @journal)
    assert_equal :invalid_journal, inspect_trial[:status]
  end

  test 'rejects an incomplete final line' do
    File.open(@journal, 'ab') { |file| file.write('{"event":') }
    assert_equal :invalid_journal, inspect_trial[:status]
  end

  test 'rejects malformed json even if the line ends normally' do
    File.binwrite(@journal, "not json\n")
    assert_equal :invalid_journal, inspect_trial[:status]
  end

  test 'does not inspect paths outside the trial directory supplied by a journal' do
    @prepared['source'] = '/videos/Film.mkv'
    write_events(@prepared)
    assert_equal :invalid_journal, inspect_trial[:status]
  end

  test 'recognizes a refusal journal with no prepared plan' do
    write_events(event('needs_review'))
    result = inspect_trial
    assert_equal :unprepared, result[:status]
    assert_equal false, result[:automatic_action]
  end

  test 'rejects impossible journal event sequences' do
    write_events(@prepared, event('completed'))
    assert_equal :invalid_journal, inspect_trial[:status]
  end

  test 'reports a conflict for a deleted asset' do
    @asset.update!(status: 'deleted')
    assert_equal :conflict, inspect_trial[:status]
  end

  test 'reports a conflict if the asset owner differs from the journal' do
    @prepared['record_id'] += 1
    write_events(@prepared)
    assert_equal :conflict, inspect_trial[:status]
  end

  test 'reports a conflict if the asset no longer exists' do
    @asset.destroy!
    assert_equal :conflict, inspect_trial[:status]
  end

  test 'reports a conflict if another asset already claims the target in the database' do
    File.rename(@source, @target)
    VideoAsset.create!(record: @record, last_known_path: @target)
    result = inspect_trial
    assert_equal :conflict, result[:status]
    assert_equal true, result[:target_claimed_by_other_asset]
  end

  test 'rejects incomplete identity metadata' do
    @prepared['identity'].delete('ino')
    write_events(@prepared)
    assert_equal :invalid_journal, inspect_trial[:status]
  end

  test 'refuses a production root before looking for a journal' do
    inspector = VideoAssets::RelocationTrialInspection.new(root: '/videos')
    assert_raises(VideoAssets::RelocationTrialInspection::Refused) do
      inspector.call(journal_path: '/videos/relocation-test.jsonl')
    end
  end

  test 'leaves files journal asset and record unchanged' do
    File.rename(@source, @target)
    write_events(@prepared, event('filesystem_renamed'), event('needs_review'))
    before = snapshot
    result = inspect_trial
    assert_equal :database_update_pending, result[:status]
    assert_equal before, snapshot
  end

  private

  def inspect_trial
    VideoAssets::RelocationTrialInspection.new(root: @root).call(journal_path: @journal)
  end

  def event(name)
    { 'event' => name, 'at' => Time.now.utc.iso8601(6) }
  end

  def write_events(*entries)
    File.binwrite(@journal, entries.map { |entry| JSON.generate(entry) + "\n" }.join)
  end

  def snapshot
    files = Dir.children(@root).sort.to_h do |name|
      path = File.join(@root, name)
      stat = File.lstat(path)
      [name, [stat.ino, stat.size, stat.mtime.to_r, stat.ctime.to_r, File.binread(path)]]
    end
    [files, @asset.reload.attributes, @record.reload.attributes]
  end
end
