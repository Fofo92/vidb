# frozen_string_literal: true

require 'json'
require 'open3'

abort 'Usage: inspect_encoder_exports.rb DIRECTORY OUTPUT.json' unless ARGV.size == 2
directory, output = ARGV
rows = Dir.children(directory).sort.filter_map do |name|
  next unless name.match?(/\AS05 E0[12] -/) && File.extname(name) == '.mkv' && !name.include?('_vf')

  path = File.join(directory, name)
  project = path.sub(/\.mkv\z/, '.json')
  out, error, status = Open3.capture3('ffprobe', '-v', 'error', '-show_streams', '-show_format', '-of', 'json', path)
  raise error unless status.success?

  { path: path, byte_size: File.size(path), modified_at: File.mtime(path).utc.iso8601(6),
    probe: JSON.parse(out), project_path: project,
    project: File.file?(project) ? JSON.parse(File.read(project)) : nil }
end
File.write(output, JSON.pretty_generate(read_only: true, files: rows))
puts JSON.generate(read_only: true, files: rows.size, projects: rows.count { |r| r[:project] }, output: output)
