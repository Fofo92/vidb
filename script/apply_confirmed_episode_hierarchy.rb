# frozen_string_literal: true

require 'json'

unless ARGV.length.between?(1, 2) && (ARGV.length == 1 || ARGV[1] == '--apply')
  abort 'Usage: bin/rails runner script/apply_confirmed_episode_hierarchy.rb CONFIRMED.json [--apply]'
end
evidence = JSON.parse(File.read(ARGV[0]))
abort 'Confirmed evidence required' unless evidence['format'] == 'vidb.confirmed_episode_hierarchy' &&
                                          evidence['version'] == 1 && evidence['confirmed_by_viewing'] == true
abort 'Only explicit local season 1 supported' unless evidence['local_season_number'] == 1

titles = evidence.fetch('episode_titles')
paths = evidence.fetch('confirmed_paths')
abort 'One confirmed path per episode required' unless paths.length == titles.length && paths.uniq == paths
paths.each_with_index do |path, index|
  expected = "S01 E#{format('%02d', index + 1)} - #{titles[index]}.m4v"
  abort "Unexpected filename: #{path}" unless File.basename(path) == expected
  abort "File missing: #{path}" unless File.file?(path)
end

report = CatalogEnrichment::ConfirmedHierarchy.new(
  record_id: evidence.fetch('record_id'), series_title: evidence.fetch('series_title'), episode_titles: titles
).call(apply: ARGV[1] == '--apply')
puts JSON.pretty_generate(report.merge(confirmed_evidence: evidence))
