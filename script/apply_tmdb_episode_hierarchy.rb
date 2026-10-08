# frozen_string_literal: true

require 'json'

unless ARGV.length.between?(4, 5) && (ARGV.length == 4 || ARGV.last == '--apply')
  abort 'Usage: bin/rails runner script/apply_tmdb_episode_hierarchy.rb MAPPING SNAPSHOT PLAN OUTPUT [--apply]'
end

inputs = ARGV.first(3).map { |path| JSON.parse(File.read(path)) }
service = CatalogEnrichment::TmdbHierarchyApplication.new(mapping: inputs[0], snapshot: inputs[1], plan: inputs[2])
report = service.call(apply: ARGV.last == '--apply')
output = Pathname.new(ARGV.fetch(3))
output.dirname.mkpath
output.write(JSON.pretty_generate(report) << "\n")
puts JSON.pretty_generate(report.except(:links))
puts output
