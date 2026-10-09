# frozen_string_literal: true

require 'json'

unless ARGV.length.between?(2, 3) && (ARGV.length == 2 || ARGV.last == '--apply')
  abort 'Usage: bin/rails runner script/import_broadcast_parts.rb EVIDENCE.json OUTPUT.json [--apply]'
end

evidence = JSON.parse(File.read(ARGV.fetch(0)))
report = CatalogEnrichment::BroadcastPartImport.new(evidence: evidence).call(apply: ARGV.include?('--apply'))
output = Pathname.new(ARGV.fetch(1))
output.dirname.mkpath
output.write(JSON.pretty_generate(report) << "\n")
puts JSON.pretty_generate(report.slice(:applied, :episodes, :files))
puts output
