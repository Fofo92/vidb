require 'test_helper'
require 'tmpdir'

class CopyReferenceRestoreTest < ActiveSupport::TestCase
  setup do
    @root = Dir.mktmpdir
    user = User.create!(email: 'copy-restore@example.com', password: 'password')
    language = LanguageVersion.create!(short_name: 'CRS', long_name: 'Restauration test')
    @record = Record.create!(french_title: 'En apnée', record_kind: 'standalone_video', language_version: language)
    @old = @record.video_assets.create!(last_known_path: File.join(@root, 'ancien.mkv'), status: 'missing',
                                        technical_details: { 'qualification' => 'VF' })
    @current = @record.video_assets.create!(last_known_path: File.join(@root, 'present.mkv'))
    backup = VideoAssets::CopyReferenceBackup.new(directory: File.join(@root, 'backup'))
    cleanup = VideoAssets::MissingCopyRetirement.new(user: user, root: @root, guard: -> {}, backup: backup)
    cleanup.call(cleanup.confirmation([@old.id]).fetch(:token))
    @path = cleanup.backup_path
    @service = VideoAssets::CopyReferenceRestore.new
  end

  teardown { FileUtils.remove_entry(@root) }

  test 'default preview does not recreate any reference' do
    assert_no_difference 'VideoAsset.count' do
      result = @service.call(@path)
      assert_equal false, result[:applied]
    end
  end

  test 'explicit restore recovers the old reference without rewinding viewing state' do
    @record.update_columns(is_seen: true, seen_state_confirmed_at: Time.current)
    before = @record.reload.attributes.slice('is_seen', 'seen_state_confirmed_at')
    @service.call(@path, apply: true)
    restored = VideoAsset.find(@old.id)
    assert_equal 'missing', restored.status
    assert_equal @old.last_known_path, restored.last_known_path
    assert_equal 'VF', restored.technical_details['qualification']
    assert_equal before, @record.reload.attributes.slice('is_seen', 'seen_state_confirmed_at')
    assert @current.reload.status_present?
  end

  test 'restore never overwrites a reference created later at the same path' do
    newer = @record.video_assets.create!(last_known_path: @old.last_known_path)
    assert_raises(ArgumentError) { @service.call(@path, apply: true) }
    assert_not VideoAsset.exists?(@old.id)
    assert newer.reload.status_present?
  end

  test 'repeated restoration cannot duplicate or overwrite records' do
    @service.call(@path, apply: true)
    assert_raises(ArgumentError) { @service.call(@path, apply: true) }
    assert_equal 2, @record.video_assets.count
  end
end
