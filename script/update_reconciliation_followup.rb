# frozen_string_literal: true

require 'json'
require 'digest'
require 'tempfile'

abort 'Usage: bin/rails runner script/update_reconciliation_followup.rb REPORT.json DIRECTORY' unless ARGV.length == 2

report_path = Pathname.new(ARGV.fetch(0))
directory = Pathname.new(ARGV.fetch(1))
directory.mkpath
ledger = directory.join('current.json')
File.open(directory.join('followup.lock'), File::RDWR | File::CREAT, 0o600) do |lock|
  lock.flock(File::LOCK_EX)
  report_bytes = report_path.read
  report = JSON.parse(report_bytes)
  previous = ledger.exist? ? JSON.parse(ledger.read) : nil
  followup = VideoAssets::ReconciliationFollowup.new(report: report, previous: previous).call
  archive = directory.join("source-#{Digest::SHA256.hexdigest(report_bytes)}.json")
  archive.write(report_bytes) unless archive.exist?
  payload = JSON.pretty_generate(followup) << "\n"
  history = directory.join("followup-#{Digest::SHA256.hexdigest(payload)}.json")
  history.write(payload) unless history.exist?
  Tempfile.create(['followup-', '.json'], directory.to_s) do |file|
    file.chmod(0o600)
    file.write(payload)
    file.flush
    file.fsync
    File.rename(file.path, ledger)
  end
  puts JSON.pretty_generate(followup.slice(:counts).merge(
                              new_paths: followup[:new_paths].size,
                              absent_since_previous: followup[:absent_since_previous].size
                            ))
  puts ledger
end
