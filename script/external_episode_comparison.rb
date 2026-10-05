# frozen_string_literal: true

require 'json'
require 'pathname'
require_relative '../app/services/catalog_enrichment/episode_comparison'

unless ARGV.length == 3
  abort 'Usage: ruby script/external_episode_comparison.rb RECONCILIATION.json EVIDENCE.json OUTPUT.json'
end

reconciliation = JSON.parse(File.read(ARGV[0]))
evidence = JSON.parse(File.read(ARGV[1]))
report = CatalogEnrichment::EpisodeComparison.new(reconciliation: reconciliation, evidence: evidence).call
output = Pathname.new(ARGV[2])
inputs = ARGV.first(2).map { |path| File.realpath(path) }
destination = output.exist? ? File.realpath(output) : output.expand_path.to_s
abort 'Output must not overwrite an input' if inputs.include?(destination)
output.dirname.mkpath
output.write(JSON.pretty_generate(report) << "\n")
puts JSON.pretty_generate(report.fetch(:summary))
puts output
