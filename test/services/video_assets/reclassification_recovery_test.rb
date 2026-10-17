# frozen_string_literal: true

require 'test_helper'
require_relative '../../support/reclassification_fixture'

class ReclassificationRecoveryTest < ActiveSupport::TestCase
  include ReclassificationFixture

  def recovery
    VideoAssets::ReclassificationRecovery.new(
      root: @root, planner: @planner, journal_directory: File.join(@root, 'journal'), volume_guard: @guard,
      file_rename: @renamer, qualification: @qualification
    )
  end

  def recover
    recovery.call(plan: @plan, asset: @asset.reload, genres: [@old.name], authorized: true)
  end

  def state
    recovery.preview_state(plan: @plan, asset: @asset.reload, genres: [@old.name])
  end

  def empty_checkpoint
    VideoAssets::RelocationJournal.new(File.join(@root, 'journal')).open(@asset) { |_file| nil }
  end

  def sql_failure
    @asset.define_singleton_method(:update!) { |**_args| raise ActiveRecord::RecordInvalid.new(self) }
    assert_raises(VideoAssets::RelocationCommit::Failed) { execute }
    @asset = VideoAsset.find(@asset.id)
  end

  test 'empty checkpoint resumes through the complete verified operation' do
    empty_checkpoint
    assert_equal :before_rename, state
    recover
    assert_equal @target, @asset.reload.last_known_path
    assert_equal [@new.name], @record.reload.genders.map(&:name)
    assert_equal %w[prepared filesystem_renamed reconciled], journal.map { |row| row['event'] }
  end

  test 'a prepared native failure resumes without duplicate prepared rows' do
    original = @renamer
    @renamer = ->(**_args) { raise Errno::EACCES }
    assert_raises(VideoAssets::RelocationCommit::Failed) { execute }
    @renamer = original
    assert_equal :before_rename, state
    recover
    assert_equal 1, journal.count { |row| row['event'] == 'prepared' }
    assert_equal @target, @asset.reload.last_known_path
  end

  test 'SQL failure is recovered without invoking any filesystem adapter again' do
    sql_failure
    assert_equal :filesystem_done, state
    @renamer = ->(**_args) { flunk 'A moved file must never be moved a second time' }
    recover
    assert_equal @target, @asset.reload.last_known_path
    assert_equal 'documented_review', @record.reload.genre_provenance['origin']
    assert_equal 1, journal.count { |row| row['event'] == 'filesystem_renamed' }
  end

  test 'already committed state closes the journal without rewriting provenance' do
    append = VideoAssets::RelocationJournal.method(:append)
    interrupted = lambda do |file, event, details = {}|
      raise IOError, 'Completion fixture' if event == 'completed'

      append.call(file, event, details)
    end
    VideoAssets::RelocationJournal.stub(:append, interrupted) do
      assert_raises(VideoAssets::RelocationCommit::Failed) { execute }
    end
    before = @record.reload.attributes.deep_dup
    assert_equal :database_done, state
    recover
    assert_equal before, @record.reload.attributes
    assert_equal 'reconciled', journal.last['event']
  end

  test 'recovery replay leaves SQL and journal completely unchanged' do
    sql_failure
    recover
    before = @record.reload.attributes.deep_dup
    rows = journal
    recover
    assert_equal before, @record.reload.attributes
    assert_equal rows, journal
  end

  test 'read only state inspection writes neither SQL nor journal' do
    sql_failure
    before = @record.reload.attributes.deep_dup
    rows = journal
    assert_equal :filesystem_done, state
    assert_equal before, @record.reload.attributes
    assert_equal rows, journal
  end

  test 'manual synopsis changes after interruption remain protected' do
    sql_failure
    @record.reload.update!(abstract: 'Corrected after interruption')
    assert_raises(VideoAssets::RelocationCommit::Failed) { recover }
    assert_equal 'Corrected after interruption', @record.reload.abstract
    assert_equal @source, @asset.reload.last_known_path
  end

  test 'manual genre correction after interruption cannot be overwritten' do
    sql_failure
    @record.reload.genders = [@new]
    assert_raises(VideoAssets::RelocationCommit::Failed) { recover }
    assert_equal 'manual_or_untracked', @record.reload.genre_provenance['origin']
    assert_equal @source, @asset.reload.last_known_path
  end

  test 'target modification with original size and restored mtime is refused' do
    sql_failure
    File.write(@target, 'changed')
    nanoseconds = @plan[:identity][:mtime_ns]
    original = Time.at(nanoseconds / 1_000_000_000, nanoseconds % 1_000_000_000, :nanosecond)
    File.utime(original, original, @target)
    assert_raises(VideoAssets::RelocationCommit::Failed) { recover }
    assert_equal @source, @asset.reload.last_known_path
    assert_equal({}, @record.reload.genre_provenance)
  end

  test 'source reappearing after a move blocks reconciliation' do
    sql_failure
    File.write(@source, 'fixture')
    assert_raises(VideoAssets::RelocationCommit::Failed) { recover }
    assert File.exist?(@target)
    assert_equal @source, @asset.reload.last_known_path
  end

  test 'a different operation cannot reuse prepared evidence' do
    sql_failure
    @qualification[:operation_id] = 'different-operation'
    assert_raises(VideoAssets::RelocationCommit::Failed) { recover }
    assert_equal @source, @asset.reload.last_known_path
  end

  test 'journal symlinks are rejected without touching their targets' do
    empty_checkpoint
    path = File.join(@root, 'journal', "relocation-#{@record.id}-#{@asset.id}.jsonl")
    File.unlink(path)
    target = File.join(@root, 'keep')
    File.write(target, 'keep')
    File.symlink(target, path)
    assert_raises(Errno::ELOOP) { state }
    assert_equal 'keep', File.read(target)
  end

  test 'a truncated journal is refused without discarding evidence' do
    empty_checkpoint
    path = File.join(@root, 'journal', "relocation-#{@record.id}-#{@asset.id}.jsonl")
    File.write(path, '{"event":')
    assert_raises(ArgumentError) { state }
    assert_equal '{"event":', File.read(path)
  end

  test 'journal writable by other users is refused' do
    empty_checkpoint
    path = File.join(@root, 'journal', "relocation-#{@record.id}-#{@asset.id}.jsonl")
    File.chmod(0o644, path)
    assert_raises(ArgumentError) { state }
  end
  test 'interruption between rename and physical checkpoint is recoverable' do
    append = VideoAssets::RelocationJournal.method(:append)
    interrupted = lambda do |file, event, details = {}|
      raise IOError, 'Physical checkpoint fixture' if event == 'filesystem_renamed'

      append.call(file, event, details)
    end
    VideoAssets::RelocationJournal.stub(:append, interrupted) do
      assert_raises(VideoAssets::RelocationCommit::Failed) { execute }
    end
    assert_equal :filesystem_done, state
    recover
    assert_equal :database_done, state
    moved = journal.find { |row| row['event'] == 'filesystem_renamed' }
    assert_equal VideoAssets::RelocationFileIdentity.call(File.lstat(@target)).as_json, moved['identity_after']
    assert_equal @target, @asset.reload.last_known_path
  end

  test 'an exception after the completion row was written is reconciled without SQL changes' do
    append = VideoAssets::RelocationJournal.method(:append)
    interrupted = lambda do |file, event, details = {}|
      append.call(file, event, details)
      raise IOError, 'After completion fixture' if event == 'completed'
    end
    VideoAssets::RelocationJournal.stub(:append, interrupted) do
      assert_raises(VideoAssets::RelocationCommit::Failed) { execute }
    end
    before = @record.reload.attributes.deep_dup
    assert_equal :database_done, state
    recover
    assert_equal before, @record.reload.attributes
    assert_equal 'reconciled', journal.last['event']
  end
end
