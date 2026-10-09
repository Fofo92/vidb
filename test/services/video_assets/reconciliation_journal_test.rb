# frozen_string_literal: true

require 'test_helper'
require 'tmpdir'

class ReconciliationJournalTest < ActiveSupport::TestCase
  test 'publication preserves history and refuses an older snapshot without replacing the ledger' do
    Dir.mktmpdir do |directory|
      journal = VideoAssets::ReconciliationJournal.new(directory: directory)
      report = { format: VideoAssets::ReconciliationReport::FORMAT,
                 version: VideoAssets::ReconciliationReport::VERSION,
                 source_inventory: { roots: ['/videos'], generated_at: '2026-10-09T10:00:00Z' },
                 observations: [] }
      assert_no_difference ['Record.count', 'VideoAsset.count'] do
        journal.call(report: report)
      end
      ledger = Pathname.new(directory).join('current.json')
      previous = ledger.read
      assert_equal 1, Dir.glob(File.join(directory, 'source-*.json')).size
      assert_equal 1, Dir.glob(File.join(directory, 'followup-*.json')).size
      report[:source_inventory][:generated_at] = '2026-10-01T00:00:00Z'
      assert_raises(ArgumentError) { journal.call(report: report) }
      assert_equal previous, ledger.read
    end
  end

  test 'automatic history is bounded without deleting manual archives' do
    Dir.mktmpdir do |directory|
      manual = Pathname.new(directory).join('source-manual.json')
      manual.write('manual evidence')
      journal = VideoAssets::ReconciliationJournal.new(directory: directory, automatic: true)
      33.times do |number|
        report = { format: VideoAssets::ReconciliationReport::FORMAT,
                   version: VideoAssets::ReconciliationReport::VERSION,
                   source_inventory: { roots: ['/videos'],
                                       generated_at: (Time.utc(2026, 10, 9) + number.minutes).iso8601 },
                   observations: [] }
        journal.call(report: report)
      end
      assert_equal 32, Dir.glob(File.join(directory, 'automatic-history/source-*.json')).size
      assert_equal 32, Dir.glob(File.join(directory, 'automatic-history/followup-*.json')).size
      assert_equal 'manual evidence', manual.read
    end
  end

end
