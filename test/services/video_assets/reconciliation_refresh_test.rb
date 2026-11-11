# frozen_string_literal: true

require 'test_helper'
require 'tmpdir'
require 'minitest/mock'

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

  test 'language qualification runs after successful imports and is included in the journal' do
    Dir.mktmpdir do |directory|
      sweep = -> { { processed: 1, copies: [{ video_asset_id: 123, status: 'qualified' }] } }
      journal = ->(report:) { report.fetch(:automatic_languages) }
      result = refresh(directory, language_sweep: sweep, journal: journal).call
      assert_equal 1, result[:processed]
    end
  end

  test 'a concurrent refresh waits without consuming the pending request then runs once' do
    Dir.mktmpdir do |directory|
      marker = Pathname.new(directory).join('refresh.request')
      VideoAssets::ReconciliationRefreshRequest.call(path: marker)
      service = refresh(directory)
      entered = Queue.new
      started = Queue.new
      worker = nil
      File.open(File.join(directory, 'refresh.lock'), File::RDWR | File::CREAT, 0o600) do |lock|
        lock.flock(File::LOCK_EX)
        perform = lambda do
          entered << true
          marker.delete
          { counts: { 'confirmed' => 1 } }
        end
        service.stub(:refresh, perform) do
          worker = Thread.new { started << true; service.call }
          started.pop
          assert_nil worker.join(0.05), 'The worker must wait rather than return skipped'
          assert entered.empty?, 'Do not enter the refresh while another worker owns the lock'
          assert marker.exist?, 'A waiting worker must preserve the request'
          lock.flock(File::LOCK_UN)
          assert worker.join(5), 'The worker must resume after the lock is released'
          assert_equal({ 'confirmed' => 1 }, worker.value.fetch(:counts))
          assert_equal 1, entered.size
          assert_not marker.exist?
        ensure
          lock.flock(File::LOCK_UN)
          worker&.kill if worker&.alive?
          worker&.join
        end
      end
    end
  end

  test 'recent files remain pending even when their titles match uniquely' do
    report = { format: VideoAssets::ReconciliationReport::FORMAT,
               version: VideoAssets::ReconciliationReport::VERSION,
               source_inventory: { format: 'vidb.video_library_inventory', version: 1, roots: ['/videos'], generated_at: '2026-10-09T10:00:00Z' },
               observations: [{ path: '/videos/recent.mkv', size: 100, status: 'exact',
                                candidates: [{ record_id: 1 }], modified_at: '2026-10-09T09:00:00Z' }] }
    result = VideoAssets::ReconciliationFollowup.new(report: report, assets: []).call
    entry = result[:entries].first
    assert_equal 'awaiting_stability', entry[:followup_status]
    assert_equal 'awaiting_stability', VideoAssets::BlockageCategory.call(entry)
  end

  private

  def refresh(directory, scanner: -> { { format: 'vidb.video_library_inventory', version: 1, roots: ['/videos'], generated_at: Time.current.iso8601, entries: [] } }, guard: -> {}, journal: ->(**) { {} }, language_sweep: -> { { processed: 0, copies: [] } })
    reporter = ->(_inventory) { { counts: { 'confirmed' => 1 } } }
    VideoAssets::ReconciliationRefresh.new(directory: directory, scanner: scanner,
                                          guard: guard, reporter: reporter, journal: journal, language_sweep: language_sweep)
  end
end
