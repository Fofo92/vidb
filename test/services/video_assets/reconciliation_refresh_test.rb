# frozen_string_literal: true

require 'test_helper'
require 'tmpdir'

class ReconciliationRefreshTest < ActiveSupport::TestCase
  test 'refresh consumes pending request and retains requests made during the scan' do
    Dir.mktmpdir do |directory|
      marker = Pathname.new(directory).join('refresh.request')
      VideoAssets::ReconciliationRefreshRequest.call(path: marker)
      assert marker.exist?
      journal = lambda do |report:|
        assert_not marker.exist?
        VideoAssets::ReconciliationRefreshRequest.call(path: marker)
        { counts: report.fetch(:counts) }
      end
      result = refresh(directory, journal: journal).call
      assert_equal({ 'confirmed' => 1 }, result[:counts])
      assert marker.exist?
    end
  end

  test 'an incomplete scan never publishes a new journal' do
    Dir.mktmpdir do |directory|
      ledger = Pathname.new(directory).join('current.json')
      ledger.write('previous')
      inventory = { roots: ['/videos'], entries: [{ type: 'inaccessible', path: '/videos/private' }] }
      scanner = -> { inventory }
      journal = ->(**) { flunk 'Incomplete scan must not publish' }
      assert_raises(ArgumentError) { refresh(directory, scanner: scanner, journal: journal).call }
      assert_equal 'previous', ledger.read
    end
  end

  test 'a missing volume stops before scanning' do
    Dir.mktmpdir do |directory|
      guard = -> { raise ArgumentError, 'Wrong UUID' }
      scanner = -> { flunk 'Do not scan an unavailable volume' }
      assert_raises(ArgumentError) { refresh(directory, scanner: scanner, guard: guard).call }
    end
  end

  test 'concurrent refreshes do not start a second scan' do
    Dir.mktmpdir do |directory|
      File.open(File.join(directory, 'refresh.lock'), File::RDWR | File::CREAT, 0o600) do |lock|
        lock.flock(File::LOCK_EX)
        assert_equal 'refresh_already_running', refresh(directory).call[:skipped]
      end
    end
  end

  test 'recent files remain pending even when their titles match uniquely' do
    report = { format: VideoAssets::ReconciliationReport::FORMAT,
               version: VideoAssets::ReconciliationReport::VERSION,
               source_inventory: { roots: ['/videos'], generated_at: '2026-10-09T10:00:00Z' },
               observations: [{ path: '/videos/recent.mkv', size: 100, status: 'exact',
                                candidates: [{ record_id: 1 }], modified_at: '2026-10-09T09:00:00Z' }] }
    result = VideoAssets::ReconciliationFollowup.new(report: report, assets: []).call
    entry = result[:entries].first
    assert_equal 'awaiting_stability', entry[:followup_status]
    assert_equal 'awaiting_stability', VideoAssets::BlockageCategory.call(entry)
  end

  private

  def refresh(directory, scanner: -> { { roots: ['/videos'], entries: [] } }, guard: -> {}, journal: ->(**) { {} })
    reporter = ->(_inventory) { { counts: { 'confirmed' => 1 } } }
    VideoAssets::ReconciliationRefresh.new(directory: directory, scanner: scanner,
                                          guard: guard, reporter: reporter, journal: journal)
  end
end
