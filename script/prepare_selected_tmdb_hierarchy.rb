# frozen_string_literal: true

require 'json'

unless ARGV.length == 2
  abort 'Usage: bin/rails runner script/prepare_selected_tmdb_hierarchy.rb PILOT_RUN_DIRECTORY OUTPUT_DIRECTORY'
end

source = Pathname.new(ARGV.fetch(0))
output = Pathname.new(ARGV.fetch(1))
abort 'Output directory already exists; choose a new path' if output.exist?

mapping = JSON.parse(source.join('mapping.json').read)
snapshot = JSON.parse(source.join('snapshot.json').read)
columns = CatalogEnrichment::TmdbHierarchyApplication::COLUMNS
catalogue = Record.pluck(*columns).map { |values| columns.zip(values).to_h }
report = CatalogEnrichment::TmdbSelectedHierarchy.new(mapping: mapping, snapshot: snapshot, catalogue: catalogue).call
output.mkpath
{ 'mapping' => report.fetch(:mapping), 'snapshot' => snapshot, 'hierarchy-plan' => report.fetch(:hierarchy_plan),
  'selection-report' => report }.each do |name, content|
  output.join("#{name}.json").write(JSON.pretty_generate(content) << "\n")
end
puts JSON.pretty_generate(report.slice(:read_only, :selected_count, :excluded_count))
puts output
