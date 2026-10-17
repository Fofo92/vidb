# frozen_string_literal: true

require 'test_helper'
require 'tmpdir'
require 'fileutils'
require 'json'

class RelocationCommitTest < ActiveSupport::TestCase
  # The service must observe a real commit, not a savepoint in a test transaction.
  self.use_transactional_tests = false

  setup do
    @root = Dir.mktmpdir('vidb-relocation-', '/tmp')
    @journal_root = Dir.mktmpdir('vidb-relocation-journal-', '/tmp')
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
    @planner = VideoAssets::RelocationPlanner.new(root: @root, builder: builder, volume_guard: -> { true })
    @plan = @planner.call(asset: @asset, genres: [])
  end

  teardown do
    @extra_asset&.destroy!
    @asset&.destroy! if @asset&.persisted?
    @record&.destroy! if @record&.persisted?
    @other_record&.destroy! if @other_record&.persisted?
    @language&.destroy! if @language&.persisted?
    FileUtils.remove_entry(@journal_root) if @journal_root && File.directory?(@journal_root)
    FileUtils.remove_entry(@root) if @root && File.directory?(@root)
  end

  test 'renames the fixture and updates its existing asset' do
    original_id = @asset.id
    result = commit
    assert_equal :completed, result[:status]
    assert_equal true, result[:database_updated]
    assert_equal @target, VideoAsset.find(original_id).last_known_path
    assert_equal @record.id, @asset.reload.record_id
    assert_equal 'matroska', @asset.container
    assert_equal 'fake mkv data', File.binread(@target)
    assert_not File.exist?(@source)
    assert_equal %w[prepared filesystem_renamed completed], events(result[:journal_path]).map { |entry| entry.fetch('event') }
    assert_equal @source, events(result[:journal_path]).first.fetch('source')
    assert_equal 0o600, File.stat(result[:journal_path]).mode & 0o777
    assert @record.reload.is_available
  end

  test 'an injected filesystem adapter receives the exact rechecked plan' do
    requests = []
    backend = Object.new
    backend.define_singleton_method(:call) do |source:, target:, identity:|
      requests << { source: source, target: target, identity: identity }
      File.rename(source, target)
    end
    result = commit(file_rename: backend)
    assert_equal :completed, result[:status]
    assert_equal [{ source: @source, target: @target, identity: @plan.fetch(:identity) }], requests
    assert_equal @target, @asset.reload.last_known_path
  end

  test 'a backend false success leaves the database path unchanged and journals inspection' do
    backend = Object.new
    backend.define_singleton_method(:call) { |**_options| nil }
    error = assert_raises(VideoAssets::RelocationCommit::Failed) { commit(file_rename: backend) }
    assert_equal @source, @asset.reload.last_known_path
    assert File.exist?(@source)
    assert_not File.exist?(@target)
    assert_equal %w[prepared needs_review], events(error.journal_path).map { |entry| entry.fetch('event') }
  end

  test 'a noncanonical stored source cannot be silently normalized into another request' do
    raw_path = @source.sub('/ancien.mkv', '//ancien.mkv')
    @asset.update!(last_known_path: raw_path)
    backend = Object.new
    backend.define_singleton_method(:call) { |**_options| raise 'must not reach backend' }
    error = assert_raises(VideoAssets::RelocationCommit::Failed) { commit(file_rename: backend) }
    assert_kind_of VideoAssets::RelocationCommit::Refused, error.cause
    assert_equal raw_path, @asset.reload.last_known_path
    assert File.exist?(@source)
    assert_not File.exist?(@target)
  end

  test 'preserves a journal and the renamed file if the database update fails' do
    writer = lambda do |asset, target|
      asset.update!(last_known_path: target)
      raise ActiveRecord::RecordInvalid.new(asset)
    end
    error = assert_raises(VideoAssets::RelocationCommit::Failed) { commit(writer: writer) }
    assert_kind_of ActiveRecord::RecordInvalid, error.cause
    assert_equal @source, @asset.reload.last_known_path
    assert_equal 'fake mkv data', File.binread(@target)
    assert_not File.exist?(@source)
    assert_equal %w[prepared filesystem_renamed needs_review], events(error.journal_path).map { |entry| entry.fetch('event') }
  end

  test 'records the filesystem result before updating the database' do
    writer = lambda do |asset, target|
      path = Dir.glob(File.join(@journal_root, 'relocation-*.jsonl')).fetch(0)
      assert_equal %w[prepared filesystem_renamed], events(path).map { |entry| entry.fetch('event') }
      assert_equal @source, VideoAsset.find(asset.id).last_known_path
      asset.update!(last_known_path: target)
    end
    assert_equal :completed, commit(writer: writer)[:status]
  end

  test 'refuses a destination that became occupied' do
    File.binwrite(@target, 'existing destination')
    error = assert_raises(VideoAssets::RelocationCommit::Failed) { commit }
    assert_equal @source, @asset.reload.last_known_path
    assert_equal 'fake mkv data', File.binread(@source)
    assert_equal 'existing destination', File.binread(@target)
    assert_equal ['needs_review'], events(error.journal_path).map { |entry| entry.fetch('event') }
  end

  test 'refuses a copy deleted since preview' do
    @asset.update!(status: 'deleted')
    assert_raises(VideoAssets::RelocationCommit::Failed) { commit }
    assert_equal 'deleted', @asset.reload.status
    assert_equal 'fake mkv data', File.binread(@source)
    assert_not File.exist?(@target)
  end

  test 'refuses a second present copy added since preview' do
    @extra_asset = VideoAsset.create!(record: @record, last_known_path: File.join(@root, 'second.mkv'))
    assert_raises(VideoAssets::RelocationCommit::Failed) { commit }
    assert_equal @source, @asset.reload.last_known_path
    assert_equal 'fake mkv data', File.binread(@source)
    assert_not File.exist?(@target)
  end

  test 'refuses a destination already assigned to another asset before renaming' do
    @other_record = Record.create!(french_title: 'Autre film de test', language_version: @language)
    @extra_asset = VideoAsset.create!(record: @other_record, last_known_path: @target)
    error = assert_raises(VideoAssets::RelocationCommit::Failed) { commit }
    assert_kind_of VideoAssets::RelocationCommit::Refused, error.cause
    assert_equal @source, @asset.reload.last_known_path
    assert_equal 'fake mkv data', File.binread(@source)
    assert_not File.exist?(@target)
  end

  test 'keeps the journal when a late database path collision rejects the update' do
    @other_record = Record.create!(french_title: 'Autre film de test', language_version: @language)
    writer = lambda do |asset, target|
      VideoAsset.create!(record: @other_record, last_known_path: target)
      asset.update!(last_known_path: target)
    end
    error = assert_raises(VideoAssets::RelocationCommit::Failed) { commit(writer: writer) }
    assert_kind_of ActiveRecord::RecordNotUnique, error.cause
    assert_equal @source, @asset.reload.last_known_path
    assert_equal 'fake mkv data', File.binread(@target)
    assert_equal 'needs_review', events(error.journal_path).last.fetch('event')
    assert_not @other_record.video_assets.exists?
  end

  test 'refuses an outer transaction without writing a journal' do
    VideoAsset.transaction do
      assert_raises(VideoAssets::RelocationCommit::Refused) { commit }
    end
    assert_empty Dir.glob(File.join(@journal_root, 'relocation-*.jsonl'))
    assert_equal @source, @asset.reload.last_known_path
    assert_equal 'fake mkv data', File.binread(@source)
  end

  test 'requires explicit authorization before any journal or file change' do
    service = VideoAssets::RelocationCommit.new(root: @root, planner: @planner,
                                              journal_directory: @journal_root, volume_guard: -> { true })
    assert_raises(VideoAssets::RelocationCommit::Refused) do
      service.call(plan: @plan, asset: @asset, genres: [])
    end
    assert_empty Dir.children(@journal_root)
    assert File.exist?(@source)
  end

  test 'volume failure prevents creation of a journal or file changes' do
    service = VideoAssets::RelocationCommit.new(root: @root, planner: @planner,
                                              journal_directory: @journal_root,
                                              volume_guard: -> { raise ArgumentError, 'Wrong volume' })
    assert_raises(ArgumentError) do
      service.call(plan: @plan, asset: @asset, genres: [], authorized: true)
    end
    assert_empty Dir.children(@journal_root)
    assert File.exist?(@source)
  end

  private

  def commit(writer: nil, file_rename: nil)
    VideoAssets::RelocationCommit.new(root: @root, planner: @planner, writer: writer, file_rename: file_rename,
                                         journal_directory: @journal_root, volume_guard: -> { true })
                                    .call(plan: @plan, asset: @asset, genres: [], authorized: true)
  end

  def events(path)
    File.readlines(path).map { |line| JSON.parse(line) }
  end
end
