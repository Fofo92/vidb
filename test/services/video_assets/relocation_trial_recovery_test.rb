# frozen_string_literal: true

require 'test_helper'
require 'tmpdir'
require 'fileutils'
require 'json'

class RelocationTrialRecoveryTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    @root = Dir.mktmpdir('vidb-relocation-', '/tmp')
    @source = File.join(@root, 'ancien.mkv')
    @target = File.join(@root, 'nouveau.mkv')
    File.binwrite(@source, 'fake mkv data')
    @language = LanguageVersion.create!(short_name: 'VF', long_name: 'Version française')
    @record = Record.create!(french_title: 'Film de test', year: 2022,
                             record_kind: 'standalone_video', language_version: @language)
    @asset = VideoAsset.create!(record: @record, last_known_path: @source,
                               byte_size: File.size(@source), container: 'matroska')
    target = @target
    builder = Object.new
    builder.define_singleton_method(:call) { |record:, genres:| target }
    planner = VideoAssets::RelocationPlanner.new(root: @root, builder: builder, volume_guard: -> { true })
    plan = planner.call(asset: @asset, genres: [])
    failure = ->(asset, _target) { raise ActiveRecord::RecordInvalid.new(asset) }
    begin
      VideoAssets::RelocationTrialCommit.new(root: @root, planner: planner, writer: failure)
                                       .call(plan: plan, asset: @asset, genres: [])
      flunk 'Fixture must fail after renaming and before updating the database'
    rescue VideoAssets::RelocationTrialCommit::Failed => error
      @journal = error.journal_path
    end
  end

  teardown do
    @extra_asset&.destroy!
    @asset&.destroy! if @asset&.persisted?
    @record&.destroy! if @record&.persisted?
    @language&.destroy! if @language&.persisted?
    FileUtils.remove_entry(@root) if @root && File.directory?(@root)
  end

  test 'recovers the database path without changing or renaming the file' do
    before = file_snapshot
    result = recover
    assert_equal :recovered, result[:status]
    assert_equal true, result[:database_updated]
    assert_equal false, result[:files_changed]
    assert_equal @target, @asset.reload.last_known_path
    assert_equal @record.id, @asset.record_id
    assert_equal 'matroska', @asset.container
    assert_equal before, file_snapshot
    assert_equal :consistent_target, inspect_trial[:status]
    assert_equal %w[prepared filesystem_renamed needs_review database_recovery_started database_recovery_completed], event_names
  end

  test 'a repeated recovery is idempotent and does not append journal events' do
    recover
    before = [@asset.reload.attributes, File.binread(@journal), file_snapshot]
    result = recover
    assert_equal :already_consistent, result[:status]
    assert_equal false, result[:database_updated]
    assert_equal before, [@asset.reload.attributes, File.binread(@journal), file_snapshot]
  end

  test 'rolls back a failed database update and permits a later retry' do
    writer = lambda do |asset, target|
      asset.update!(last_known_path: target)
      raise ActiveRecord::RecordInvalid.new(asset)
    end
    before = file_snapshot
    error = assert_raises(VideoAssets::RelocationTrialRecovery::Failed) { recover(writer: writer) }
    assert_kind_of ActiveRecord::RecordInvalid, error.cause
    assert_equal @journal, error.journal_path
    assert_equal @source, @asset.reload.last_known_path
    assert_equal before, file_snapshot
    assert_equal 'database_recovery_failed', event_names.last
    assert_equal :database_update_pending, inspect_trial[:status]
    assert_equal :recovered, recover[:status]
    assert_equal @target, @asset.reload.last_known_path
  end

  test 'can retry a recovery interrupted before the database commit' do
    append_interrupted_event
    assert_equal :database_update_pending, inspect_trial[:status]
    assert_equal :recovered, recover[:status]
    assert_equal @target, @asset.reload.last_known_path
    assert_equal %w[database_recovery_started database_recovery_failed database_recovery_started database_recovery_completed], event_names.last(4)
  end

  test 'does not update the database again if an interrupted recovery already committed' do
    append_interrupted_event
    @asset.update!(last_known_path: @target)
    before = [@asset.reload.attributes, File.binread(@journal), file_snapshot]
    result = recover
    assert_equal :already_consistent, result[:status]
    assert_equal false, result[:database_updated]
    assert_equal before, [@asset.reload.attributes, File.binread(@journal), file_snapshot]
  end

  test 'refuses a source path that has become occupied again' do
    File.binwrite(@source, 'new source')
    assert_refused_unchanged
  end

  test 'refuses a changed target of the same size' do
    File.binwrite(@target, 'X' * @asset.byte_size)
    time = File.mtime(@target) + 2
    File.utime(time, time, @target)
    assert_refused_unchanged
  end

  test 'refuses a missing target' do
    File.unlink(@target)
    assert_refused_unchanged
  end

  test 'refuses a deleted asset' do
    @asset.update!(status: 'deleted')
    assert_refused_unchanged
  end

  test 'refuses a target claimed by another asset' do
    @extra_asset = VideoAsset.create!(record: @record, last_known_path: @target)
    assert_refused_unchanged
  end

  test 'refuses a truncated journal without changing any existing evidence' do
    File.open(@journal, 'ab') { |file| file.write('{"event":') }
    assert_refused_unchanged
  end

  test 'refuses an outer transaction before writing anything' do
    VideoAsset.transaction { assert_refused_unchanged }
  end

  test 'refuses a journal already locked by another recovery' do
    File.open(@journal, File::RDWR) do |file|
      file.flock(File::LOCK_EX)
      assert_refused_unchanged
    end
  end

  test 'refuses a source symlink and does not follow it' do
    File.symlink(@target, @source)
    assert_refused_unchanged
  end

  test 'refuses a journal without a prepared plan' do
    File.binwrite(@journal, JSON.generate(event: 'needs_review', at: Time.now.utc.iso8601(6)) + "\n")
    assert_refused_unchanged
  end

  test 'rejects a no-op writer instead of falsely reporting success' do
    assert_raises(VideoAssets::RelocationTrialRecovery::Failed) { recover(writer: ->(*) {}) }
    assert_equal @source, @asset.reload.last_known_path
    assert_equal :database_update_pending, inspect_trial[:status]
    assert_equal 'database_recovery_failed', event_names.last
  end

  private

  def recover(writer: nil)
    VideoAssets::RelocationTrialRecovery.new(root: @root, writer: writer).call(journal_path: @journal)
  end

  def inspect_trial
    VideoAssets::RelocationTrialInspection.new(root: @root).call(journal_path: @journal)
  end

  def append_interrupted_event
    File.open(@journal, 'ab') do |file|
      file.write(JSON.generate(event: 'database_recovery_started', at: Time.now.utc.iso8601(6)) + "\n")
    end
  end

  def event_names
    File.readlines(@journal).map { |line| JSON.parse(line).fetch('event') }
  end

  def file_snapshot
    [@source, @target].to_h do |path|
      if File.symlink?(path)
        [path, [:symlink, File.readlink(path)]]
      elsif File.exist?(path)
        stat = File.lstat(path)
        [path, [stat.dev, stat.ino, stat.size, stat.mtime.to_r, stat.ctime.to_r, File.binread(path)]]
      else
        [path, :missing]
      end
    end
  end

  def assert_refused_unchanged
    before = [@asset.reload.attributes, File.binread(@journal), file_snapshot]
    assert_raises(VideoAssets::RelocationTrialRecovery::Refused) { recover }
    assert_equal before, [@asset.reload.attributes, File.binread(@journal), file_snapshot]
  end
end
