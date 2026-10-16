# frozen_string_literal: true

require 'test_helper'
require 'tmpdir'
require 'fileutils'

class RelocationTrialExecutorTest < ActiveSupport::TestCase
  Copy = Struct.new(:id, :record_id, :record, :last_known_path, :byte_size, keyword_init: true) do
    def status_present? = true
  end
  Film = Struct.new(:video_assets, keyword_init: true)

  setup do
    @root = Dir.mktmpdir('vidb-relocation-', '/tmp')
    @source = File.join(@root, 'ancien.mkv')
    @target = File.join(@root, 'nouveau.mkv')
    File.binwrite(@source, 'fake mkv data')
    record = Film.new(video_assets: [])
    @asset = Copy.new(id: 1, record_id: 2, record: record,
                      last_known_path: @source, byte_size: File.size(@source))
    record.video_assets << @asset
    target = @target
    builder = Object.new
    builder.define_singleton_method(:call) { |record:, genres:| target }
    @planner = VideoAssets::RelocationPlanner.new(root: @root, builder: builder, volume_guard: -> { true })
    @plan = @planner.call(asset: @asset, genres: [])
  end

  teardown do
    FileUtils.remove_entry(@root) if @root && File.directory?(@root)
  end

  test 'renames a fixture while preserving inode and contents' do
    inode = File.stat(@source).ino
    result = execute
    assert_equal :renamed, result[:status]
    assert_equal false, result[:database_updated]
    assert_not File.exist?(@source)
    assert_equal inode, File.stat(@target).ino
    assert_equal 'fake mkv data', File.binread(@target)
    assert_equal @source, @asset.last_known_path
  end

  test 'refuses a preview that was not ready' do
    @plan[:ready] = false
    assert_raises(VideoAssets::RelocationTrialExecutor::Refused) { execute }
    assert_original
  end

  test 'refuses an occupied destination' do
    File.binwrite(@target, 'existing')
    assert_raises(VideoAssets::RelocationTrialExecutor::Refused) { execute }
    assert_original
    assert_equal 'existing', File.binread(@target)
  end

  test 'refuses a same size modification since preview' do
    File.binwrite(@source, 'X' * @asset.byte_size)
    time = File.mtime(@source) + 2
    File.utime(time, time, @source)
    assert_raises(VideoAssets::RelocationTrialExecutor::Refused) { execute }
    assert_equal 'X' * @asset.byte_size, File.binread(@source)
    assert_not File.exist?(@target)
  end

  test 'refuses a missing source' do
    File.unlink(@source)
    assert_raises(VideoAssets::RelocationTrialExecutor::Refused) { execute }
    assert_not File.exist?(@target)
  end

  test 'refuses a json added since preview' do
    File.binwrite(File.join(@root, 'ancien.json'), '{}')
    assert_raises(VideoAssets::RelocationTrialExecutor::Refused) { execute }
    assert_original
  end

  test 'never overwrites a destination created immediately before native rename' do
    executor = VideoAssets::RelocationTrialExecutor.new(root: @root, planner: @planner)
    native_rename = executor.method(:rename_without_replace)
    race = lambda do |fd, source, target|
      File.binwrite(@target, 'late destination')
      native_rename.call(fd, source, target)
    end
    assert_raises(Errno::EEXIST) { execute(renamer: race) }
    assert_original
    assert_equal 'late destination', File.binread(@target)
  end

  test 'preserves the source when the rename fails' do
    failure = ->(*) { raise Errno::EACCES, 'simulated error' }
    assert_raises(Errno::EACCES) { execute(renamer: failure) }
    assert_original
    assert_not File.exist?(@target)
  end

  test 'refuses a second execution of the same plan' do
    execute
    assert_raises(VideoAssets::RelocationTrialExecutor::Refused) { execute }
    assert_equal 'fake mkv data', File.binread(@target)
  end

  test 'refuses the production root before consulting the planner' do
    service = VideoAssets::RelocationTrialExecutor.new(root: '/videos', planner: nil)
    assert_raises(VideoAssets::RelocationTrialExecutor::Refused) do
      service.call(plan: @plan, asset: @asset, genres: [])
    end
    assert_original
  end

  test 'refuses a trial directory accessible to other users' do
    File.chmod(0o755, @root)
    assert_raises(VideoAssets::RelocationTrialExecutor::Refused) { execute }
    assert_original
  end

  private

  def execute(renamer: nil)
    VideoAssets::RelocationTrialExecutor.new(root: @root, planner: @planner, renamer: renamer)
                                       .call(plan: @plan, asset: @asset, genres: [])
  end

  def assert_original
    assert_equal 'fake mkv data', File.binread(@source)
  end
end
