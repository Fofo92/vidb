# frozen_string_literal: true
require 'json'
require 'fileutils'

results = []
current_record = nil
operation = nil
job_lock = nil
begin
  valid_args = ARGV.size.between?(1, 2) && (ARGV.size == 1 || ARGV.last == '--apply')
  raise ArgumentError, 'Usage: runner apply_film_metadata_proposals.rb INPUT.json [--apply]' unless valid_args
  apply = ARGV.last == '--apply'
  unless Rails.env.production? && ActiveRecord::Base.connection_db_config.database == 'vidb_production'
    raise ArgumentError, 'Production vidb_production required'
  end
  input = JSON.parse(File.read(ARGV.first))
  entries = input.fetch('entries')
  operation = input.fetch('operation_id')
  ids = entries.map { |entry| entry.fetch('local').fetch('record_id') }
  valid = input['format'] == 'vidb.initial_film_metadata_application' && input['version'] == 1 &&
          input['source_policy'] == 'film_metadata_proposal_v2' &&
          operation.match?(/\Ainitial-films-[0-9a-f]{20}\z/) && entries.size == input.fetch('expected_records') &&
          ids.uniq.size == ids.size && ids.all? { |id| id.is_a?(Integer) && id.positive? }
  raise ArgumentError, 'Unexpected initial application input' unless valid
  work = Rails.root.join('tmp', 'film-metadata-application', operation)
  FileUtils.mkdir_p(work)
  job_lock = File.open(work.join('.lock'), File::RDWR | File::CREAT, 0o600)
  raise ArgumentError, 'This operation is already running' unless job_lock.flock(File::LOCK_EX | File::LOCK_NB)
  service = CatalogEnrichment::FilmMetadataApplication.new(
    journal_directory: '/srv/vidb/shared/film-metadata-journal', operation: operation
  )
  entries.sort_by { |entry| entry.dig('local', 'record_id') }.each_with_index do |entry, index|
    current_record = entry.dig('local', 'record_id')
    result = service.call(entry: entry, apply: apply)
    # Keep large field evidence in the source input and durable journal, not duplicated in the summary.
    result = result.except(:attributes, :gender_ids) if result[:status] == 'ready'
    results << result
    warn "Métadonnées : #{index + 1}/#{entries.size} fiches" if ((index + 1) % 100).zero?
  end
  report = { format: 'vidb.initial_film_metadata_result', version: 1, status: 'completed',
             mode: apply ? 'apply' : 'preview', operation_id: operation, total: results.size,
             counts: results.group_by { |row| row.fetch(:status) }.transform_values(&:size), records: results,
             database_changed: results.any? { |row| row[:status] == 'applied' },
             year_values_changed: results.count { |row| row[:year_value_changed] },
             genres_added: results.count { |row| row[:genres_added] }, video_files_changed: false }
  file = work.join(apply ? 'apply.json' : 'preview.json')
  temporary = file.sub_ext('.tmp')
  temporary.write(JSON.pretty_generate(report))
  File.rename(temporary, file)
  puts JSON.pretty_generate(report.merge(work_report: file.to_s))
rescue StandardError => e
  report = { format: 'vidb.initial_film_metadata_result', version: 1, status: 'stopped', operation_id: operation,
             failed_record_id: current_record, error_class: e.class.name,
             error: e.is_a?(ArgumentError) ? e.message : 'Application interrupted; the current work was rolled back or needs journal recovery.',
             total: results.size, counts: results.group_by { |row| row.fetch(:status) }.transform_values(&:size), records: results,
             database_changed: results.any? { |row| row[:status] == 'applied' }, video_files_changed: false }
  puts JSON.pretty_generate(report)
  exit 1
ensure
  job_lock&.close
end
