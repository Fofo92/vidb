# frozen_string_literal: true

require 'test_helper'
require 'tmpdir'
require 'fileutils'

class RelocationPlannerSafetyTest < ActiveSupport::TestCase
  Copy = Struct.new(:id, :record_id, :record, :last_known_path, :byte_size, keyword_init: true) do
    def status_present? = true
  end
  Film = Struct.new(:video_assets, keyword_init: true)

  setup do
    @root = Dir.mktmpdir('vidb-relocation-', '/tmp')
    @source = File.join(@root, 'ancien.mkv')
    @target = File.join(@root, 'nouveau.mkv')
    File.binwrite(@source, 'fake mkv data')
    @record = Film.new(video_assets: [])
    @asset = Copy.new(id: 1, record_id: 2, record: @record,
                      last_known_path: @source, byte_size: File.size(@source))
    @record.video_assets << @asset
  end

  teardown do
    FileUtils.remove_entry(@root) if @root && File.directory?(@root)
  end

  test 'rechecks an unchanged preview' do
    service = planner
    plan = service.call(asset: @asset, genres: [])
    result = service.recheck(plan: plan, asset: @asset, genres: [])
    assert result[:ready], result[:checks].inspect
    assert_equal false, result[:execution_authorized]
  end

  test 'detects a same size modification after the preview' do
    service = planner
    plan = service.call(asset: @asset, genres: [])
    original_time = File.mtime(@source)
    File.binwrite(@source, 'X' * @asset.byte_size)
    File.utime(original_time + 2, original_time + 2, @source)
    result = service.recheck(plan: plan, asset: @asset, genres: [])
    assert result[:checks][:size_matches]
    assert_equal false, result[:checks][:identity_matches]
    assert_equal false, result[:ready]
  end

  test 'detects a replacement inode with the original size and mtime' do
    service = planner
    plan = service.call(asset: @asset, genres: [])
    original_time = File.mtime(@source)
    replacement = File.join(@root, 'replacement.mkv')
    File.binwrite(replacement, 'Y' * @asset.byte_size)
    File.utime(original_time, original_time, replacement)
    File.rename(replacement, @source)
    result = service.recheck(plan: plan, asset: @asset, genres: [])
    assert result[:checks][:size_matches]
    assert_equal false, result[:checks][:identity_matches]
    assert_equal false, result[:ready]
  end

  test 'refuses a changed target when rechecking' do
    plan = planner.call(asset: @asset, genres: [])
    @target = File.join(@root, 'different.mkv')
    result = planner.recheck(plan: plan, asset: @asset, genres: [])
    assert_equal false, result[:checks][:same_plan]
    assert_equal false, result[:ready]
  end

  test 'rechecks newly occupied destinations' do
    service = planner
    plan = service.call(asset: @asset, genres: [])
    File.binwrite(@target, 'do not overwrite')
    result = service.recheck(plan: plan, asset: @asset, genres: [])
    assert_equal false, result[:ready]
    assert_equal 'do not overwrite', File.binread(@target)
  end

  test 'refuses a symbolic parent directory even inside the root' do
    real_directory = File.join(@root, 'real')
    link_directory = File.join(@root, 'link')
    Dir.mkdir(real_directory)
    File.symlink(real_directory, link_directory)
    File.rename(@source, File.join(real_directory, 'ancien.mkv'))
    @asset.last_known_path = File.join(link_directory, 'ancien.mkv')
    @target = File.join(link_directory, 'nouveau.mkv')
    assert_blocked(:no_symlink_ancestors)
  end

  test 'refuses a configured root that is itself a symlink' do
    linked_root = File.join(@root, 'linked-root')
    File.symlink(@root, linked_root)
    @asset.last_known_path = File.join(linked_root, 'ancien.mkv')
    target = File.join(linked_root, 'nouveau.mkv')
    builder = Object.new
    builder.define_singleton_method(:call) { |record:, genres:| target }
    service = VideoAssets::RelocationPlanner.new(root: linked_root, builder: builder, volume_guard: -> { true })
    result = service.call(asset: @asset, genres: [])
    assert_equal false, result[:checks][:no_symlink_ancestors]
    assert_equal false, result[:ready]
  end
  private

  def planner(volume_guard: -> { true })
    target = @target
    builder = Object.new
    builder.define_singleton_method(:call) { |record:, genres:| target }
    VideoAssets::RelocationPlanner.new(root: @root, builder: builder, volume_guard: volume_guard)
  end

  def assert_blocked(check)
    plan = planner.call(asset: @asset, genres: [])
    assert_equal false, plan[:checks].fetch(check), plan[:checks].inspect
    assert_equal false, plan[:ready]
    assert_equal false, plan[:execution_authorized]
    plan
  end

  def snapshot
    Dir.children(@root).sort.to_h do |name|
      path = File.join(@root, name)
      stat = File.lstat(path)
      [name, [stat.ino, stat.size, stat.mtime.to_r, stat.mode, File.binread(path)]]
    end
  end
end
