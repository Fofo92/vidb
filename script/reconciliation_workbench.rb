# frozen_string_literal: true
require 'json'
arguments = ARGV.dup
if arguments.first == '--proposals'
  abort 'Usage: --proposals PROPOSITIONS.json' unless arguments.size == 2
  items = ReconciliationWorkbench::Proposals.new.call(JSON.parse(File.read(arguments.last)))
  puts JSON.pretty_generate(proposals: items.size, automatic_approval: false)
elsif arguments == ['--refresh'] || arguments == ['--apply']
  run = ReconciliationRun.create!(mode: arguments.first.delete_prefix('--') == 'apply' ? 'apply' : 'refresh')
  result = ReconciliationWorkbench::Worker.new.poll
  puts JSON.pretty_generate(run_id: run.id, result: result)
  exit 1 if result[:error]
elsif arguments.empty?
  result = ReconciliationWorkbench::Worker.new.poll
  puts JSON.pretty_generate(result)
  exit 1 if result[:error]
else
  abort 'Usage: bin/rails runner script/reconciliation_workbench.rb [--refresh|--apply|--proposals FILE.json]'
end
