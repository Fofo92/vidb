# frozen_string_literal: true

require 'json'

unless ARGV.length == 3
  abort 'Usage: bin/rails runner script/plan_blanca_copy_languages.rb IMPORT.json REPORT.json LANGUAGE_BATCH.json'
end

evidence = JSON.parse(File.read(ARGV.fetch(0)))
report = VideoAssets::ConfirmedSeriesLanguagePlan.new(import_evidence: evidence).call
output = Pathname.new(ARGV.fetch(1))
output.dirname.mkpath
output.write(JSON.pretty_generate(report) << "\n")
manifest_output = Pathname.new(ARGV.fetch(2))
manifest_output.dirname.mkpath
manifest_output.write(JSON.pretty_generate(report.fetch(:manifest)) << "\n")
puts JSON.pretty_generate(report.slice(:applied, :counts))
puts output
puts manifest_output
