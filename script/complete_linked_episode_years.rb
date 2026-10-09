# frozen_string_literal: true

require 'json'

root_id = Integer(ARGV.fetch(0))
output = Pathname.new(ARGV.fetch(1))
apply = ARGV.drop(2)
abort 'Usage: ROOT_RECORD_ID OUTPUT.json [--apply]' unless [[], ['--apply']].include?(apply)

report = CatalogEnrichment::LinkedEpisodeYears.new(root_record_id: root_id, apply: apply == ['--apply']).call
output.dirname.mkpath
output.write(JSON.pretty_generate(report) << "\n")
puts JSON.pretty_generate(report.slice(:applied, :root_record_id, :total))
puts output
