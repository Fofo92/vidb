# frozen_string_literal: true

require 'json'

abort 'Usage: bin/rails runner script/update_reconciliation_followup.rb REPORT.json DIRECTORY' unless ARGV.length == 2

report = JSON.parse(Pathname.new(ARGV.fetch(0)).read)
directory = Pathname.new(ARGV.fetch(1))
followup = VideoAssets::ReconciliationJournal.new(directory: directory).call(report: report)
puts JSON.pretty_generate(followup.slice(:counts).merge(
                            new_paths: followup[:new_paths].size,
                            absent_since_previous: followup[:absent_since_previous].size
                          ))
puts directory.join('current.json')
