# frozen_string_literal: true

require 'json'

unless ARGV.length == 4
  abort 'Usage: bin/rails runner script/compare_broadcast_parts.rb FOLLOWUP.json ROOT_ID SERIES_DIRECTORY OUTPUT.json'
end

followup = JSON.parse(File.read(ARGV.fetch(0)))
unless followup['format'] == VideoAssets::ReconciliationFollowup::FORMAT && followup['version'] == 1
  abort 'Unsupported reconciliation followup'
end
root = Record.find(Integer(ARGV.fetch(1)))
abort 'Expected a root record' if root.ancestry.present?

report = CatalogEnrichment::BroadcastPartComparison.new(
  entries: followup.fetch('entries'), root: root, directory: ARGV.fetch(2)
).call
report[:confirmed_broadcast_basis] = 'Pascal: M6 broadcasts each Blanca episode in two parts, confirmed 2026-10-09' if root.id == 3442
output = Pathname.new(ARGV.fetch(3))
output.dirname.mkpath
output.write(JSON.pretty_generate(report) << "\n")
puts JSON.pretty_generate(report.slice(:read_only, :file_count, :part_groups, :counts))
puts output
