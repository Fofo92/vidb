require 'test_helper'
require 'tmpdir'

class InventorySnapshotTest < ActiveSupport::TestCase
  setup do
    @directory = Dir.mktmpdir
    @path = File.join(@directory, 'current.json')
    @service = VideoAssets::InventorySnapshot.new(path: @path)
    @document = { format: 'vidb.reconciliation_followup', version: 1,
                  inventory_at: Time.current.iso8601, source_inventory: { roots: ['/videos'] },
                  entries: [{ path: '/videos/Jo_old.mkv', size: 3, modified_at: 2.days.ago.iso8601 }] }
  end

  teardown { FileUtils.remove_entry(@directory) }

  test 'reads the completed inventory without changing it' do
    File.write(@path, JSON.generate(@document))
    previous = File.binread(@path)
    assert_equal '/videos/Jo_old.mkv', @service.call[:entries].first[:path]
    assert_equal previous, File.binread(@path)
  end

  test 'missing malformed and wrong scope inventories do not establish an absence' do
    assert_nil @service.call
    File.write(@path, 'not json')
    assert_nil @service.call
    File.write(@path, JSON.generate(@document.merge(source_inventory: { roots: ['/other'] })))
    assert_nil @service.call
    File.write(@path, '[]')
    assert_nil @service.call
  end

  test 'invalid entries and dates are rejected as a whole' do
    File.write(@path, JSON.generate(@document.merge(entries: [nil])))
    assert_nil @service.call
    File.write(@path, JSON.generate(@document.merge(inventory_at: 'invalid')))
    assert_nil @service.call
  end
end
