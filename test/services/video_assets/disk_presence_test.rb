require 'test_helper'
require 'tmpdir'

class DiskPresenceTest < ActiveSupport::TestCase
  setup do
    @directory = Dir.mktmpdir
    @path = File.join(@directory, 'copie.mkv')
    language = LanguageVersion.create!(short_name: 'VF', long_name: 'Français')
    @record = Record.create!(language_version: language, french_title: 'Présence', record_kind: 'standalone_video')
    @asset = @record.video_assets.create!(last_known_path: @path, byte_size: 3, observed_at: Time.current)
    @service = VideoAssets::DiskPresence.new(root: @directory, guard: -> {})
  end

  teardown { FileUtils.remove_entry(@directory) }

  def inventory(entries = [])
    { format: 'vidb.video_library_inventory', version: 1, roots: [@directory], generated_at: Time.current.iso8601, entries: entries }
  end

  def restore_file(content = 'abc')
    File.write(@path, content)
    File.utime(2.days.ago.to_time, 2.days.ago.to_time, @path)
    [{ type: 'file', path: @path, size: File.size(@path), modified_at: File.mtime(@path).iso8601 }]
  end

  test 'complete scan preserves recording history and marks missing once' do
    @service.call(inventory)
    assert_equal 'missing', @asset.reload.status
    assert_equal true, @record.reload.is_recorded
    assert_equal false, @record.is_available
    @service.call(inventory)
    assert_equal 1, @asset.reload.technical_details['disk_presence_history'].size
  end

  test 'valid return restores availability but a changed file cannot restore it' do
    @service.call(inventory)
    @service.call(inventory(restore_file('different')))
    assert_equal 'missing', @asset.reload.status
    @service.call(inventory(restore_file))
    assert_equal 'present', @asset.reload.status
    assert_equal true, @record.reload.is_available
    assert_equal 2, @asset.technical_details['disk_presence_history'].size
  end

  test 'manual deletion is never undone by a scan' do
    @asset.update!(status: 'deleted')
    @service.call(inventory(restore_file))
    assert_equal 'deleted', @asset.reload.status
  end

  test 'incomplete scans and scan races do not mark absent copies' do
    assert_raises(ArgumentError) { @service.call(inventory([{ type: 'inaccessible', path: @directory }])) }
    restore_file
    assert_raises(ArgumentError) { @service.call(inventory) }
    assert_equal 'present', @asset.reload.status
  end

  test 'volume loss rolls back absence and derived availability' do
    checks = 0
    guard = -> { checks += 1; raise 'Volume lost' if checks == 2 }
    service = VideoAssets::DiskPresence.new(root: @directory, guard: guard)
    assert_raises(RuntimeError) { service.call(inventory) }
    assert_equal 'present', @asset.reload.status
    assert_equal true, @record.reload.is_available
  end

  test 'a remaining present copy keeps the work available' do
    other_path = File.join(@directory, 'autre.mkv')
    File.write(other_path, 'abc')
    File.utime(2.days.ago.to_time, 2.days.ago.to_time, other_path)
    @record.video_assets.create!(last_known_path: other_path, byte_size: 3, observed_at: Time.current)
    entry = { type: 'file', path: other_path, size: 3, modified_at: File.mtime(other_path).iso8601 }
    @service.call(inventory([entry]))
    assert_equal 'missing', @asset.reload.status
    assert_equal true, @record.reload.is_available
  end

  test 'legacy metadata validation does not prevent refreshing derived availability' do
    @record.update_columns(length_in_mn: 1)
    @service.call(inventory)
    assert_equal false, @record.reload.is_available
    assert_equal 1, @record.length_in_mn
  end
end
