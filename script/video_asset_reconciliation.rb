# frozen_string_literal: true

require "json"

inventory_path = ARGV.fetch(0) do
  abort "Usage: bin/rails runner script/video_asset_reconciliation.rb INVENTORY.json [OUTPUT.json]"
end
inventory = JSON.parse(File.read(inventory_path))
report = VideoAssets::ReconciliationReport.new(inventory: inventory).call
snapshot_date = Time.iso8601(report.dig(:source_inventory, :generated_at)).to_date
default_output = Rails.root.join(
  "tmp",
  "video-asset-reconciliation-#{snapshot_date}.json"
)
output_path = ARGV[1] ? Pathname.new(ARGV[1]) : default_output
output_path.dirname.mkpath
output_path.write(JSON.pretty_generate(report) << "\n")
puts output_path
