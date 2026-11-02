require 'test_helper'
require 'tmpdir'

class CopyRelinkTest < ActiveSupport::TestCase
  setup do
    @directory = Dir.mktmpdir
    @old = File.join(@directory, 'Jo.mkv')
    @target = File.join(@directory, 'Jo_old.mkv')
    File.write(@target, 'abc')
    File.utime(2.days.ago.to_time, 2.days.ago.to_time, @target)
    @user = User.create!(email: 'relink@example.com', password: 'password')
    language = LanguageVersion.create!(short_name: 'REL', long_name: 'Version test')
    @record = Record.create!(french_title: 'Jo', language_version: language, record_kind: 'standalone_video')
    @asset = @record.video_assets.create!(last_known_path: @old, byte_size: 3, observed_at: Time.current,
                                          duration_minutes: 17, technical_details: { 'original_evidence' => 'kept' })
    entry = { path: @target, size: 3, modified_at: File.mtime(@target).iso8601 }
    @snapshot = { entries: [entry], inventory_at: Time.current.iso8601 }
    @service = VideoAssets::CopyRelink.new(@asset, user: @user, root: @directory, guard: -> {})
  end

  teardown { FileUtils.remove_entry(@directory) }

  test 'the default volume guard receives its required root without a custom guard' do
    service = VideoAssets::CopyRelink.new(@asset, user: @user, root: @directory)
    assert_instance_of VideoAssets::CopyRelink, service
  end

  def confirmation
    reader = Struct.new(:call).new(@snapshot)
    VideoAssets::InventorySnapshot.stub(:new, -> { reader }) { @service.confirmation(@target) }
  end

  test 'manual rename retains the copy identity metadata and files' do
    File.write(@old, 'new encoding')
    project = File.join(@directory, 'Jo.json')
    File.write(project, 'unchanged project')
    id = @asset.id
    @service.call(confirmation)
    assert_equal id, @asset.reload.id
    assert_equal @target, @asset.last_known_path
    assert_equal 'present', @asset.status
    assert_equal 17, @asset.duration_minutes
    assert_equal 'kept', @asset.technical_details['original_evidence']
    assert_equal 'manual_inventory_review', @asset.technical_details['relocation_history'].last['origin']
    assert_equal 'abc', File.read(@target)
    assert_equal 'new encoding', File.read(@old)
    assert_equal 'unchanged project', File.read(project)
    assert_equal 1, @record.video_assets.count
  end

  test 'opening confirmation does not change the copy' do
    assert confirmation.present?
    assert_equal @old, @asset.reload.last_known_path
    assert File.exist?(@target)
  end

  test 'changing the file after confirmation prevents reassociation' do
    token = confirmation
    File.write(@target, 'different')
    assert_raises(ArgumentError) { @service.call(token) }
    assert_equal @old, @asset.reload.last_known_path
  end

  test 'changing the copy or beginning a deletion invalidates a confirmation' do
    token = confirmation
    @asset.update!(technical_details: { 'copy_removal_pending' => { 'id' => 'pending' } })
    assert_raises(ArgumentError) { @service.call(token) }
    assert_equal @old, @asset.reload.last_known_path
  end

  test 'an existing association at the destination is never replaced' do
    token = confirmation
    @record.video_assets.create!(last_known_path: @target)
    assert_raises(ArgumentError) { @service.call(token) }
    assert_equal @old, @asset.reload.last_known_path
  end

  test 'invalid expired or wrong user confirmations do not change the copy' do
    assert_raises(ArgumentError) { @service.call('invalid') }
    token = confirmation
    travel 16.minutes do
      assert_raises(ArgumentError) { @service.call(token) }
    end
    other = VideoAssets::CopyRelink.new(@asset, user: Struct.new(:id).new(@user.id + 1),
                                       root: @directory, guard: -> {})
    assert_raises(ArgumentError) { other.call(token) }
    assert_equal @old, @asset.reload.last_known_path
  end

  test 'deleted copies are not resurrected' do
    @asset.update!(status: 'deleted')
    assert_raises(ArgumentError) { confirmation }
  end

  test 'a symbolic destination cannot be confirmed' do
    actual = File.join(@directory, 'actual.mkv')
    File.rename(@target, actual)
    File.symlink(actual, @target)
    assert_raises(ArgumentError) { confirmation }
  end

  test 'loss of the volume rolls back the association' do
    token = confirmation
    count = 0
    guard = -> { count += 1; raise ArgumentError, 'Volume lost' if count == 2 }
    service = VideoAssets::CopyRelink.new(@asset, user: @user, root: @directory, guard: guard)
    assert_raises(ArgumentError) { service.call(token) }
    assert_equal @old, @asset.reload.last_known_path
  end
end
