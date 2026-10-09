# frozen_string_literal: true

require 'json'

abort 'Usage: bin/rails runner script/classify_reconciliation_blockages.rb FOLLOWUP.json OUTPUT.json' unless ARGV.length == 2

followup = JSON.parse(File.read(ARGV.fetch(0)))
result = VideoAssets::BlockageSummary.new(followup: followup).call
output = Pathname.new(ARGV.fetch(1))
output.dirname.mkpath
output.write(JSON.pretty_generate(result) << "\n")
puts JSON.pretty_generate(result.slice(:total_files, :counts))
puts output
