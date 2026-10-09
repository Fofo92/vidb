# frozen_string_literal: true

require 'json'
require 'tmpdir'
require Rails.root.join('script/video_library_inventory').to_s

unless ARGV.length == 2
  abort 'Usage: bin/rails runner script/prepare_encoding_series_pilot.rb CONFIG.json OUTPUT_DIRECTORY'
end

config = JSON.parse(File.read(ARGV.fetch(0)))
directory = Pathname.new(ARGV.fetch(1))
guard = VideoAssets::ReconciliationVolumeGuard.new(root: '/videos')
guard.call
inventory = VideoLibraryInventory::Scanner.new(roots: [config.fetch('directory')], include_all_files: true).call
guard.call
client = CatalogEnrichment::TmdbClient.new(cache_dir: directory.join('tmdb-cache'), refresh: true)
snapshot = CatalogEnrichment::TmdbSeriesSnapshot.new(client: client, series_id: config.fetch('tmdb_series_id')).call
columns = CatalogEnrichment::TmdbHierarchyApplication::COLUMNS
catalogue = Record.pluck(*columns).map { |values| columns.zip(values).to_h }
report = CatalogEnrichment::EncodingSeriesPilot.new(config: config, snapshot: snapshot,
                                                   inventory: inventory, catalogue: catalogue).call
guard.call
directory.mkpath
run = Pathname.new(Dir.mktmpdir('run-', directory.to_s))
artifacts = { 'pilot-report' => report, 'snapshot' => snapshot, 'mapping' => report.fetch(:mapping),
              'hierarchy-plan' => report.fetch(:hierarchy_plan), 'inventory' => inventory }
artifacts.each do |name, content|
  next unless content

  run.join("#{name}.json").write(JSON.pretty_generate(content) << "\n")
end
summary = report.slice(:read_only, :root_record_id, :tmdb_series_id, :counts, :project_only_count)
puts JSON.pretty_generate(summary.merge(hierarchy_summary: report.dig(:hierarchy_plan, :summary)))
puts run
