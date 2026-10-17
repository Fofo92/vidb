# frozen_string_literal: true
require 'json'
require 'digest'
require 'fileutils'

results = []
lock = nil
begin
  raise ArgumentError, 'Usage: runner SCRIPT INPUT.json [--apply]' unless ARGV.size.between?(1, 2) && (ARGV.size == 1 || ARGV.last == '--apply')
  apply = ARGV.last == '--apply'
  raise ArgumentError, 'Production vidb_production required' unless Rails.env.production? && ActiveRecord::Base.connection_db_config.database == 'vidb_production'
  raw = File.binread(ARGV.first)
  input = JSON.parse(raw)
  expected_ids = [1408, 2787, 3646, 3924, 4479, 4515, 7009, 7118, 7120]
  raise ArgumentError, 'Unexpected reviewed scope' unless input['format'] == 'vidb.reviewed_film_years' && input['version'] == 1 && input.fetch('entries').map { |e| e.dig('local', 'record_id') } == expected_ids
  operation = 'reviewed-years-' + Digest::SHA256.hexdigest(raw)[0, 20]
  directory = Rails.root.join('tmp', 'reviewed-film-years', operation)
  FileUtils.mkdir_p(directory)
  lock = File.open(directory.join('.lock'), File::RDWR | File::CREAT, 0o600)
  raise ArgumentError, 'This reviewed operation is already running' unless lock.flock(File::LOCK_EX | File::LOCK_NB)
  service = CatalogEnrichment::FilmMetadataApplication.new(journal_directory: '/srv/vidb/shared/film-metadata-journal', operation: operation)
  prepared = directory.join('prepared.json')
  unless apply
    client = CatalogEnrichment::TmdbFilmClient.new(cache_dir: Rails.root.join('tmp', 'tmdb-film-cache'))
    matcher = CatalogEnrichment::ReviewedFilmIdentity.new
    reference = CatalogEnrichment::FilmReleaseReference.new
    entries = input.fetch('entries').map do |entry|
      local = entry.fetch('local')
      movie = client.movie(id: entry.dig('review', 'tmdb_id'))
      identity = matcher.call(local: local, movie: movie, review: entry.fetch('review'))
      dated = reference.call(movie: movie, release_dates: client.release_dates(id: movie.fetch('id')))
      date = Date.iso8601(dated.fetch('release_date'))
      { 'status' => 'candidate', 'local' => local, 'identity' => identity.deep_stringify_keys,
        'proposal' => { 'source' => { 'provider' => 'tmdb', 'external_id' => movie.fetch('id'), 'url' => "https://www.themoviedb.org/movie/#{movie.fetch('id')}" },
          'year' => { 'status' => 'candidate', 'current' => local['year'], 'proposed' => date.year,
                      'date' => date.iso8601, 'year_basis' => 'first_release', 'reference' => dated.fetch('_vidb_release_evidence') },
          'genres' => { 'status' => 'preserved' } } }
    end
    temporary = directory.join('prepared.tmp')
    temporary.write(JSON.pretty_generate(entries))
    File.rename(temporary, prepared)
  end
  entries = JSON.parse(prepared.read)
  raise ArgumentError, 'Prepared scope changed' unless entries.map { |e| e.dig('local', 'record_id') } == expected_ids
  entries.each do |entry|
    row = service.call(entry: entry, apply: apply).except(:attributes, :gender_ids)
    results << row
  end
  output = directory.join(apply ? 'apply.json' : 'preview.json')
  report = { status: 'completed', mode: apply ? 'apply' : 'preview', operation_id: operation,
             total: results.size, counts: results.group_by { |r| r.fetch(:status) }.transform_values(&:size),
             records: results, year_values_changed: results.count { |r| r[:year_value_changed] },
             database_changed: results.any? { |r| r[:status] == 'applied' }, video_files_changed: false,
             work_report: output.to_s }
  output.write(JSON.pretty_generate(report))
  puts JSON.pretty_generate(report)
rescue StandardError => e
  puts JSON.pretty_generate(status: 'stopped', error_class: e.class.name,
                            error: e.is_a?(ArgumentError) ? e.message : 'Reviewed year preparation/application failed; completed records remain journaled.',
                            records: results, video_files_changed: false)
  exit 1
ensure
  lock&.close
end
