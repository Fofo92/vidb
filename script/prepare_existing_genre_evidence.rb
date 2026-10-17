# frozen_string_literal: true
require 'json'
require 'digest'
require 'fileutils'

results = []
lock = nil
begin
  raise ArgumentError, 'Usage: runner SCRIPT INPUT.json' unless ARGV.one?
  raise ArgumentError, 'Production vidb_production required' unless Rails.env.production? && ActiveRecord::Base.connection_db_config.database == 'vidb_production'
  raw = File.binread(ARGV.first)
  input = JSON.parse(raw)
  entries = input.fetch('entries')
  ids = entries.map { |entry| entry.dig('metadata', 'record_id') }
  raise ArgumentError, 'Unexpected genre evidence scope' unless input['format'] == 'vidb.existing_genre_evidence' && input['version'] == 1 && entries.size == 50 && ids.uniq.size == 50
  work = Rails.root.join('tmp', 'genre-evidence', Digest::SHA256.hexdigest(raw))
  FileUtils.mkdir_p(work)
  lock = File.open(work.join('.lock'), File::RDWR | File::CREAT, 0o600)
  raise ArgumentError, 'Genre evidence preparation already running' unless lock.flock(File::LOCK_EX | File::LOCK_NB)
  client = CatalogEnrichment::TmdbFilmClient.new(cache_dir: Rails.root.join('tmp', 'tmdb-film-cache'))
  service = CatalogEnrichment::ExistingGenreConcordance.new
  entries.each_with_index do |entry, index|
    expected = entry.fetch('metadata')
    snapshot = Record.transaction do
      Record.connection.execute('SET TRANSACTION ISOLATION LEVEL REPEATABLE READ, READ ONLY')
      record = Record.find(expected.fetch('record_id'))
      actual = { 'record_id' => record.id, 'french_title' => record.french_title, 'original_title' => record.original_title.to_s,
                 'year' => record.year, 'year_basis' => record.year_basis, 'year_evidence' => record.year_evidence,
                 'genres' => record.genders.reload.map(&:name).sort, 'abstract' => record.abstract }
      baseline = expected.slice(*actual.keys)
      baseline['original_title'] = baseline['original_title'].to_s
      raise ArgumentError, "Record changed since the reviewed snapshot: #{record.id}" unless actual == baseline
      raise ArgumentError, 'Qualified year and identity evidence required' unless record.year_basis == 'first_release' && record.year_evidence.dig('identity', 'supported') == true
      actual
    end
    movie_id = snapshot.fetch('year_evidence').fetch('external_id')
    movie = client.movie(id: movie_id)
    decision = service.call(current: snapshot.fetch('genres'), external: movie.fetch('genres'), review_flags: entry.fetch('review_flags'))
    results << decision.merge(record_id: snapshot.fetch('record_id'), asset_id: expected.fetch('asset_id'),
                              title: snapshot.fetch('french_title'), local: snapshot, external_genres: movie.fetch('genres'),
                              source: { provider: 'tmdb', external_id: movie_id, url: "https://www.themoviedb.org/movie/#{movie_id}" },
                              review_flags: entry.fetch('review_flags'), execution_authorized: false)
    warn "Genres : #{index + 1}/#{entries.size}" if ((index + 1) % 10).zero?
  end
  output = work.join('report.json')
  report = { format: 'vidb.existing_genre_evidence_report', version: 1, total: results.size,
             counts: results.group_by { |row| row.fetch(:status) }.transform_values(&:size), records: results,
             database_changed: false, video_files_changed: false, execution_authorized: false, work_report: output.to_s }
  temporary = work.join('report.tmp')
  temporary.write(JSON.pretty_generate(report))
  File.rename(temporary, output)
  puts JSON.pretty_generate(report)
rescue StandardError => e
  puts JSON.pretty_generate(status: 'stopped', error_class: e.class.name,
                            error: e.is_a?(ArgumentError) ? e.message : 'Genre evidence collection failed; no database write was requested.',
                            processed: results.size, database_changed: false, video_files_changed: false)
  exit 1
ensure
  lock&.close
end
