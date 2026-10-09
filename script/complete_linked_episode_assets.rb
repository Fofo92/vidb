# frozen_string_literal: true

require 'json'

unless ARGV.length.between?(3, 4) && (ARGV.length == 3 || ARGV.last == '--apply')
  abort 'Usage: bin/rails runner script/complete_linked_episode_assets.rb EVIDENCE SNAPSHOT OUTPUT [--apply]'
end

evidence = JSON.parse(File.read(ARGV.fetch(0)))
snapshot = JSON.parse(File.read(ARGV.fetch(1)))
report = CatalogEnrichment::LinkedEpisodeCompletion.new(evidence: evidence, snapshot: snapshot)
                                                  .call(apply: ARGV.last == '--apply')
output = Pathname.new(ARGV.fetch(2))
output.dirname.mkpath
output.write(JSON.pretty_generate(report) << "\n")
puts JSON.pretty_generate(report.slice(:applied, :total, :metadata_total, :metadata_labels))
puts output
