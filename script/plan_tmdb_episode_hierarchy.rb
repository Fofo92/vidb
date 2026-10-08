# frozen_string_literal: true

require 'json'

unless ARGV.length.between?(2, 3)
  abort 'Usage: bin/rails runner script/plan_tmdb_episode_hierarchy.rb MAPPING.json SNAPSHOT.json [OUTPUT.json]'
end

mapping = JSON.parse(File.read(ARGV.fetch(0)))
snapshot = JSON.parse(File.read(ARGV.fetch(1)))
columns = %w[id french_title original_title record_kind ancestry rank]
catalogue = Record.pluck(*columns).map { |values| columns.zip(values).to_h }
report = CatalogEnrichment::TmdbHierarchyPlan.new(mapping: mapping, snapshot: snapshot, catalogue: catalogue).call
output = ARGV[2] ? Pathname.new(ARGV[2]) : Rails.root.join('tmp/poirot-hierarchy-plan.json')
output.dirname.mkpath
output.write(JSON.pretty_generate(report) << "\n")
puts JSON.pretty_generate(report.slice(:read_only, :summary))
puts output
