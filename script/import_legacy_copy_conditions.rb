# frozen_string_literal: true

# Default: preview only. No rename, deletion, ffprobe or disk access in either mode.
raise 'Aucun argument attendu' unless ARGV.empty?

puts JSON.pretty_generate(VideoAssets::ConditionMarkerImport.new.call(
  apply: ENV['VIDB_APPLY_COPY_CONDITIONS'] == 'YES'
))
