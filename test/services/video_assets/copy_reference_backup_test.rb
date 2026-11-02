require 'test_helper'
require 'tmpdir'

class CopyReferenceBackupTest < ActiveSupport::TestCase
  Row = Struct.new(:attributes, :record)
  Owner = Struct.new(:id, :attributes)

  setup do
    @root = Dir.mktmpdir
    @directory = File.join(@root, 'private')
    @service = VideoAssets::CopyReferenceBackup.new(directory: @directory)
    owner = Owner.new(10, { 'id' => 10, 'is_seen' => true, 'seen_state_confirmed_at' => Time.current })
    @row = Row.new({ 'id' => 20, 'record_id' => 10, 'status' => 'missing',
                     'technical_details' => { 'qualification' => 'VF confirmée' } }, owner)
    @user = Struct.new(:id).new(1)
  end

  teardown { FileUtils.remove_entry(@root) }

  test 'backup is durable private and contains all reference attributes and viewing context' do
    path = @service.write([@row], user: @user)
    assert_equal 0o600, File.stat(path).mode & 0o777
    assert_equal 0o700, File.stat(@directory).mode & 0o777
    data = VideoAssets::CopyReferenceBackup.read(path)
    assert_equal @row.attributes, data['assets'].first
    assert_equal true, data['records'].first['is_seen']
    assert_equal 1, data['user_id']
  end

  test 'successive operations never overwrite an earlier backup' do
    first = @service.write([@row], user: @user)
    second = @service.write([@row], user: @user)
    assert_not_equal first, second
    assert File.file?(first)
    assert File.file?(second)
  end

  test 'altered backup data is rejected' do
    path = @service.write([@row], user: @user)
    envelope = JSON.parse(File.read(path))
    envelope['data']['assets'].first['id'] = 999
    File.write(path, JSON.generate(envelope))
    assert_raises(ArgumentError) { VideoAssets::CopyReferenceBackup.read(path) }
  end

  test 'public backup folders are refused' do
    Dir.mkdir(@directory, 0o755)
    assert_raises(ArgumentError) { @service.write([@row], user: @user) }
    assert_empty Dir.children(@directory)
  end

  test 'symbolic backup folders are refused' do
    target = File.join(@root, 'actual')
    Dir.mkdir(target, 0o700)
    File.symlink(target, @directory)
    assert_raises(ArgumentError) { @service.write([@row], user: @user) }
    assert_empty Dir.children(target)
  end

  test 'backup file symbolic links are not followed' do
    path = @service.write([@row], user: @user)
    link = File.join(@root, 'link.json')
    File.symlink(path, link)
    assert_raises(SystemCallError) { VideoAssets::CopyReferenceBackup.read(link) }
  end
end
