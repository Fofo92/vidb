# frozen_string_literal: true

require 'json'
require Rails.root.join('script/video_library_inventory').to_s

abort 'Usage: bin/rails runner script/refresh_reconciliation_followup.rb DIRECTORY' unless ARGV.length == 1

scanner = VideoLibraryInventory::Scanner.new(roots: ['/videos'], include_all_files: true)
result = VideoAssets::ReconciliationRefresh.new(directory: ARGV.first, scanner: scanner).call
puts JSON.pretty_generate(result.slice(:counts, :inventory_at, :skipped))
