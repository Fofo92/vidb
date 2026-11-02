require 'test_helper'
require 'tmpdir'

class AbsentCopyPathTest < ActiveSupport::TestCase
  setup do
    @root = Dir.mktmpdir
    @path = File.join(@root, 'Ancienne copie_vf.mkv')
    @service = VideoAssets::AbsentCopyPath.new(root: @root)
  end

  teardown { FileUtils.remove_entry(@root) if File.directory?(@root) }

  test 'an absent file or absent descendant directory is confirmed without creation' do
    assert @service.call(@path)
    assert @service.call(File.join(@root, 'removed', 'copy.mkv'))
    assert_empty Dir.children(@root)
  end

  test 'an existing file is refused without changing its content' do
    File.write(@path, 'keep')
    assert_raises(ArgumentError) { @service.call(@path) }
    assert_equal 'keep', File.read(@path)
  end

  test 'an existing directory is not an absent file' do
    Dir.mkdir(@path)
    assert_raises(ArgumentError) { @service.call(@path) }
  end

  test 'a broken symbolic link is an existing entry and is refused' do
    File.symlink(File.join(@root, 'nonexistent'), @path)
    assert_raises(ArgumentError) { @service.call(@path) }
    assert File.symlink?(@path)
  end

  test 'a symbolic parent is refused even when the final file is absent' do
    directory = File.join(@root, 'link')
    File.symlink(@root, directory)
    assert_raises(ArgumentError) { @service.call(File.join(directory, 'absent.mkv')) }
  end

  test 'permission failures are never interpreted as absence' do
    File.stub(:lstat, ->(_path) { raise Errno::EACCES }) do
      assert_raises(Errno::EACCES) { @service.call(@path) }
    end
  end

  test 'outside and noncanonical paths are refused' do
    [File.join(@root, '..', 'other.mkv'), '/tmp/outside.mkv', nil, "#{@root}/bad\0name"].each do |path|
      assert_raises(ArgumentError) { @service.call(path) }
    end
  end

  test 'loss of the root is not accepted as an absent copy' do
    FileUtils.remove_entry(@root)
    assert_raises(Errno::ENOENT) { @service.call(@path) }
  end
end
