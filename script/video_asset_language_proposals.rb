# frozen_string_literal: true

require 'json'

abort 'Usage: bin/rails runner script/video_asset_language_proposals.rb [OUTPUT.json]' if ARGV.size > 1
assets = VideoAsset.where(status: 'present').includes(:record, :language_version).order(:id)
proposals = assets.map { |asset| VideoAssets::LanguageProposal.new(asset).call }
report = {
  format: 'vidb.video_asset_language_proposals', version: 2,
  generated_at: Time.current.iso8601, applied: false,
  counts: proposals.group_by { |proposal| proposal.fetch(:status) }.transform_values(&:size),
  copies: proposals
}
output = ARGV.first ? Pathname.new(ARGV.first) : Rails.root.join('tmp', 'video-asset-language-proposals.json')
output.dirname.mkpath
output.write(JSON.pretty_generate(report) << "\n")
puts JSON.pretty_generate(report.slice(:applied, :counts))
puts output
