# frozen_string_literal: true

require 'json'

path = ARGV.fetch(0) { abort 'Usage: bin/rails runner script/complete_confirmed_copy_details.rb EVIDENCE.json [--apply]' }
evidence = JSON.parse(File.read(path))
report = CatalogEnrichment::ConfirmedCopyDetails.new(evidence: evidence).call(apply: ARGV.include?('--apply'))
puts JSON.pretty_generate(report)
