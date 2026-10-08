# frozen_string_literal: true

require 'json'

unless ARGV.length.between?(3, 4)
  abort 'Usage: bin/rails runner script/tmdb_series_comparison.rb TMDB_ID REPORT.json SERIES_DIRECTORY [--refresh]'
end

series_id = Integer(ARGV.fetch(0))
reconciliation = JSON.parse(File.read(ARGV.fetch(1)))
client = CatalogEnrichment::TmdbClient.new(
  cache_dir: Rails.root.join('tmp/tmdb-cache'), refresh: ARGV.include?('--refresh')
)
snapshot = CatalogEnrichment::TmdbSeriesSnapshot.new(client: client, series_id: series_id).call
columns = %w[id french_title original_title record_kind ancestry rank]
catalogue = Record.pluck(*columns).map { |values| columns.zip(values).to_h }
report = CatalogEnrichment::TmdbEpisodeComparison.new(
  snapshot: snapshot, reconciliation: reconciliation, directory: ARGV.fetch(2), catalogue: catalogue
).call
output = Rails.root.join("tmp/tmdb-series-#{series_id}-comparison.json")
output.dirname.mkpath
output.write(JSON.pretty_generate(report) << "\n")
Rails.root.join("tmp/tmdb-series-#{series_id}-snapshot.json").write(JSON.pretty_generate(snapshot) << "\n")
puts JSON.pretty_generate(report.slice(:read_only, :summary))
puts output
