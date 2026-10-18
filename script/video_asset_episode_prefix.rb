require 'json'
require 'optparse'

options = { apply: false }
OptionParser.new do |parser|
  parser.on('--directory PATH') { |value| options[:directory] = value }
  parser.on('--series-title TITLE') { |value| options[:series_title] = value }
  parser.on('--journal PATH') { |value| options[:journal_path] = value }
  parser.on('--apply') { options[:apply] = true }
end.parse!(ARGV)
abort 'Arguments requis : --directory PATH --series-title TITLE --journal PATH [--apply]' unless
  %i[directory series_title journal_path].all? { |key| options[key].present? }

apply = options.delete(:apply)
result = VideoAssets::UnlinkedEpisodePrefixRename.new(root: '/videos', **options).call(apply: apply)
VideoAssets::ReconciliationRefreshRequest.call if apply
puts JSON.pretty_generate(result)
