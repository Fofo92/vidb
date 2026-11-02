# Usage with the Rails environment loaded: rails runner script/restore_copy_reference_backup.rb BACKUP [--apply]
require 'json'

abort 'Usage : BACKUP [--apply]' unless ARGV.size.between?(1, 2) && (ARGV[1].nil? || ARGV[1] == '--apply')
result = VideoAssets::CopyReferenceRestore.new.call(ARGV.fetch(0), apply: ARGV[1] == '--apply')
puts JSON.pretty_generate(result)
