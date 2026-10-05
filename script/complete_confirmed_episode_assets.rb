# frozen_string_literal: true

require 'json'

unless ARGV.length.between?(1, 2) && (ARGV.length == 1 || ARGV[1] == '--apply')
  abort 'Usage: bin/rails runner script/complete_confirmed_episode_assets.rb EVIDENCE.json [--apply]'
end

evidence = JSON.parse(File.read(ARGV[0]))
report = CatalogEnrichment::ConfirmedCompletion.new(evidence: evidence).call(apply: ARGV[1] == '--apply')
puts JSON.pretty_generate(report)
