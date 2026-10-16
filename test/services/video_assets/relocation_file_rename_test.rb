# frozen_string_literal: true

require 'test_helper'
require 'tmpdir'
require 'fileutils'

class RelocationFileRenameTest < ActiveSupport::TestCase
  setup do
    @root = Dir.mktmpdir('vidb-relocation-', '/tmp')
    @directory = File.join(@root, 'Films', 'Espionnage')
    FileUtils.mkdir_p(@directory)
    @source = File.join(@directory, 'ancien.mkv')
    @target = File.join(@directory, 'nouveau.mkv')
    File.binwrite(@source, 'fixture contents')
    @identity = VideoAssets::RelocationFileIdentity.call(File.lstat(@source))
  end

  teardown do
    FileUtils.remove_entry(@root)
  end

  test 'renames in nested directories preserving the inode and contents' do
    rename
    assert_not File.exist?(@source)
    assert_equal 'fixture contents', File.binread(@target)
    assert_equal @identity[:ino], File.stat(@target).ino
    assert_equal @identity[:dev], File.stat(@target).dev
  end

  test 'never overwrites an existing destination' do
    File.binwrite(@target, 'occupied')
    assert_raises(Errno::EEXIST) { rename }
    assert_equal 'occupied', File.binread(@target)
    assert_equal 'fixture contents', File.binread(@source)
  end

  test 'never overwrites a dangling destination link' do
    File.symlink('missing', @target)
    assert_raises(Errno::EEXIST) { rename }
    assert File.symlink?(@target)
    assert File.exist?(@source)
  end

  test 'refuses changed identity even for equal-sized content' do
    changed_time = File.lstat(@source).mtime - 120
    File.binwrite(@source, 'different data!!')
    # Make the identity change explicit, independent of filesystem clock precision.
    File.utime(changed_time, changed_time, @source)
    assert_equal @identity[:size], File.size(@source)
    assert_not_equal @identity[:mtime_ns], VideoAssets::RelocationFileIdentity.call(File.lstat(@source))[:mtime_ns]
    assert_raises(ArgumentError) { rename }
    assert_not File.exist?(@target)
  end

  test 'refuses a symlink in any ancestor' do
    actual = File.join(@root, 'actual')
    File.rename(File.join(@root, 'Films'), actual)
    File.symlink(actual, File.join(@root, 'Films'))
    assert_raises(SystemCallError) { rename }
    assert File.exist?(@source)
    assert_not File.exist?(@target)
  end

  test 'refuses a symlink source' do
    File.rename(@source, "#{@source}.original")
    File.symlink("#{@source}.original", @source)
    assert_raises(Errno::ELOOP) { rename }
    assert File.symlink?(@source)
  end

  test 'a destination appearing immediately before the native rename stays intact' do
    native = lambda do |fd, source, target|
      File.binwrite(@target, 'late occupant')
      VideoAssets::RelocationNativeRename.new.call(fd, source, target)
    end
    assert_raises(Errno::EEXIST) { rename(native: native) }
    assert_equal 'late occupant', File.binread(@target)
    assert File.exist?(@source)
  end

  test 'native failure preserves source and does not fall back' do
    assert_raises(Errno::EACCES) { rename(native: ->(*) { raise Errno::EACCES }) }
    assert_equal 'fixture contents', File.binread(@source)
    assert_not File.exist?(@target)
  end

  test 'refuses paths into different directories or paths containing dot segments' do
    original = @target
    @target = File.join(@root, 'other.mkv')
    assert_raises(ArgumentError) { rename }
    @target = "#{@directory}/../Espionnage/nouveau.mkv"
    assert_raises(ArgumentError) { rename }
    assert_not File.exist?(original)
  end

  test 'verifies visible identity after the native operation' do
    native = lambda do |fd, source, target|
      VideoAssets::RelocationNativeRename.new.call(fd, source, target)
      File.binwrite(@target, 'unexpected replacement')
    end
    assert_raises(ArgumentError) { rename(native: native) }
    assert_not File.exist?(@source)
    assert_equal 'unexpected replacement', File.binread(@target)
  end

  private

  def rename(native: VideoAssets::RelocationNativeRename.new)
    VideoAssets::RelocationFileRename.new(native: native).call(source: @source, target: @target, identity: @identity)
  end
end
