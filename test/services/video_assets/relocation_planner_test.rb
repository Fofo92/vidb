# frozen_string_literal: true

require 'test_helper'
require 'tmpdir'
require 'fileutils'

class RelocationPlannerTest < ActiveSupport::TestCase
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

  test 'plans an unchanged isolated mkv without authorizing execution' do
    plan = planner.call(asset: @asset, genres: [])
    assert plan[:ready], plan[:checks].inspect
    assert_equal @source, plan[:source]
    assert_equal @target, plan[:target]
    assert_equal false, plan[:execution_authorized]
    assert_equal File.stat(@source).ino, plan[:identity][:ino]
  end

  test 'refuses an occupied destination without changing its contents' do
    File.binwrite(@target, 'existing destination')
    assert_blocked(:destination_free)
    assert_equal 'existing destination', File.binread(@target)
  end

  test 'refuses a dangling destination symlink' do
    File.symlink(File.join(@root, 'missing'), @target)
    assert_blocked(:destination_free)
    assert File.symlink?(@target)
  end

  test 'refuses a missing source' do
    File.unlink(@source)
    plan = assert_blocked(:source_regular)
    assert_nil plan[:identity]
  end

  test 'refuses a source whose size changed' do
    File.binwrite(@source, 'changed size')
    # Use an explicitly different size, independent of fixture wording.
    File.open(@source, 'ab') { |file| file.write('additional bytes') }
    assert_blocked(:size_matches)
  end

  test 'refuses a source without an expected size' do
    @asset.byte_size = nil
    assert_blocked(:size_matches)
  end

  test 'refuses a symbolic source' do
    actual = File.join(@root, 'actual.mkv')
    File.rename(@source, actual)
    File.symlink(actual, @source)
    assert_blocked(:source_regular)
  end

  test 'refuses a failed volume check' do
    guard = -> { raise ArgumentError, 'unexpected volume' }
    plan = planner(volume_guard: guard).call(asset: @asset, genres: [])
    assert_equal false, plan[:checks][:volume]
    assert_equal false, plan[:ready]
  end

  test 'refuses a move into another directory' do
    @target = File.join(@root, 'another', 'new.mkv')
    assert_blocked(:same_directory)
  end

  test 'refuses a target outside the configured root' do
    @target = File.join(File.dirname(@root), 'outside.mkv')
    assert_blocked(:target_inside_root)
  end

  test 'refuses an adjacent encoder json' do
    File.binwrite(File.join(@root, 'ancien.video_encoder-export.json'), '{}')
    assert_blocked(:no_adjacent_json)
  end

  test 'ignores an unrelated json' do
    File.binwrite(File.join(@root, 'unrelated.json'), '{}')
    plan = planner.call(asset: @asset, genres: [])
    assert plan[:ready], plan[:checks].inspect
  end

  test 'refuses multiple present copies' do
    @record.video_assets << Copy.new(id: 3)
    assert_blocked(:single_present_copy)
  end

  test 'refuses an unchanged path' do
    @target = @source
    assert_blocked(:different_path)
  end

  test 'produces the same plan and leaves the fixture unchanged' do
    before = snapshot
    service = planner
    first = service.call(asset: @asset, genres: [])
    second = service.call(asset: @asset, genres: [])
    assert_equal first, second
    assert_equal before, snapshot
    assert_not File.exist?(@target)
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
