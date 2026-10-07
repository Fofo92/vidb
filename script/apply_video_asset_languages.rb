# frozen_string_literal: true

require 'json'

unless ARGV.size.between?(1, 2) && (ARGV.size == 1 || ARGV.last == '--apply')
  abort 'Usage: bin/rails runner script/apply_video_asset_languages.rb MANIFEST.json [--apply]'
end
evidence = JSON.parse(File.read(ARGV.first))
report = VideoAssets::LanguageBatch.new(evidence: evidence).call(apply: ARGV.last == '--apply')
name = report[:applied] ? 'video-asset-languages-applied.json' : 'video-asset-languages-preview.json'
output = Rails.root.join('tmp', name)
output.dirname.mkpath
output.write(JSON.pretty_generate(report) << "\n")
puts JSON.pretty_generate(report.slice(:applied, :total, :changes))
puts output
