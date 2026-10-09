# frozen_string_literal: true

require 'json'

unless ARGV.length == 4
  abort 'Usage: bin/rails runner script/prepare_linked_episode_completion.rb CONFIG MAPPING INVENTORY OUTPUT'
end

config = JSON.parse(File.read(ARGV.fetch(0)))
mapping = JSON.parse(File.read(ARGV.fetch(1)))
inventory = JSON.parse(File.read(ARGV.fetch(2)))
output = Pathname.new(ARGV.fetch(3))
abort 'Output already exists; choose a new path' if output.exist?

valid = config['format'] == 'vidb.linked_episode_completion_config' && config['version'] == 1 &&
        mapping['format'] == 'vidb.local_tmdb_episode_mapping' && mapping['version'] == 1 &&
        inventory['format'] == 'vidb.video_library_inventory' && inventory['version'] == 1 &&
        inventory['roots'] == [config.fetch('directory')]
valid &&= %w[root_record_id tmdb_series_id].all? { |key| mapping.fetch(key) == config.fetch(key) }
abort 'Configuration, mapping and inventory do not agree' unless valid

files = inventory.fetch('entries').select { |entry| entry['type'] == 'file' }.index_by { |entry| entry.fetch('path') }
copies = mapping.fetch('episodes').map do |entry|
  path = entry.fetch('observed_path')
  file = files.fetch(path)
  unless file.fetch('size') == entry.fetch('observed_size') &&
         file.fetch('modified_at') == entry.fetch('observed_modified_at')
    abort "Mapping and inventory differ: #{path}"
  end

  entry.slice('tmdb_episode_id', 'local_season', 'local_episode').merge(
    'path' => path, 'size' => file.fetch('size'), 'modified_at' => file.fetch('modified_at')
  )
end
evidence = config.except('format').merge(
  'format' => 'vidb.linked_episode_completion', 'total' => copies.size, 'copies' => copies,
  'source_inventory' => inventory.slice('format', 'version', 'generated_at', 'roots')
)
candidates = CatalogEnrichment::LinkedCopyCandidates.new(evidence)
candidates.entries.each { |entry| candidates.owner(entry) }
output.dirname.mkpath
output.write(JSON.pretty_generate(evidence) << "\n")
puts JSON.pretty_generate(read_only: true, total: copies.size, root_record_id: evidence.fetch('root_record_id'))
puts output
