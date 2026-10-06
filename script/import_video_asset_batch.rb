# frozen_string_literal: true

require 'json'

path = ARGV.fetch(0) { abort 'Usage: bin/rails runner script/import_video_asset_batch.rb BATCH.json [--apply]' }
abort 'Unexpected argument' unless (ARGV.drop(1) - ['--apply']).empty?
report = VideoAssets::BatchImport.new(evidence: JSON.parse(File.read(path))).call(apply: ARGV.include?('--apply'))
output = Rails.root.join('tmp', "video-asset-batch-#{ARGV.include?('--apply') ? 'applied' : 'preview'}.json")
output.write(JSON.pretty_generate(report) << "\n")
puts JSON.pretty_generate(report.slice(:applied, :total))
puts output
