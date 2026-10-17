# frozen_string_literal: true
require 'json'
require 'digest'
require 'fileutils'

begin
  current_record_id = nil
  raise 'Usage: runner prepare_film_metadata_proposals.rb GLOBAL_REPORT.json' unless ARGV.one?
  raise 'Production vidb_production required' unless Rails.env.production? && ActiveRecord::Base.connection_db_config.database == 'vidb_production'
  input = JSON.parse(File.read(ARGV.first))
  raise 'Complete read-only global film report required' unless input['format'] == 'vidb.films_global_preview' && input['scan_complete'] == true && input['execution_authorized'] == false
  metadata = input.fetch('plans').map { |entry| entry.fetch('metadata') } + input.fetch('blocked')
  groups = metadata.group_by { |row| row.fetch('record_id') }
  fingerprint = Digest::SHA256.hexdigest(File.binread(ARGV.first))
  directory = Rails.root.join('tmp', 'film-metadata-proposals', fingerprint, 'v2')
  FileUtils.mkdir_p(directory)
  lock = File.open(directory.join('.lock'), File::RDWR | File::CREAT, 0o600)
  raise 'Another film preparation is running' unless lock.flock(File::LOCK_EX | File::LOCK_NB)
  client = CatalogEnrichment::TmdbFilmClient.new(cache_dir: Rails.root.join('tmp', 'tmdb-film-cache'))
  searcher = CatalogEnrichment::FilmSearchSnapshot.new(client: client)
  release_reference = CatalogEnrichment::FilmReleaseReference.new
  matcher = CatalogEnrichment::FilmIdentityComparison.new
  proposer = CatalogEnrichment::FilmMetadataProposal.new
  known = Gender.pluck(:name)
  results = []
  groups.sort.each_with_index do |(id, copies), index|
    current_record_id = id
    local = copies.first.slice('record_id', 'french_title', 'original_title', 'year', 'year_basis', 'year_evidence', 'genres', 'abstract')
    raise "Inconsistent snapshots for work #{id}" unless copies.all? { |row| row.slice(*local.keys) == local }
    snapshot = Record.transaction do
      Record.connection.execute('SET TRANSACTION ISOLATION LEVEL REPEATABLE READ, READ ONLY')
      record = Record.find(id)
      actual = { 'record_id' => id, 'french_title' => record.french_title, 'original_title' => record.original_title.to_s,
                 'year' => record.year, 'year_basis' => record.year_basis, 'year_evidence' => record.year_evidence,
                 'genres' => record.genders.order(:name).pluck(:name), 'abstract' => record.abstract }
      raise "Metadata changed since report: #{id}" unless actual == local
      actual
    end
    path = directory.join("record-#{id}.json")
    if path.file?
      saved = JSON.parse(path.read)
      if saved['local'] == snapshot && saved['policy'] == 'film_metadata_proposal_v2'
        results << saved
        next
      end
    end
    search = searcher.call(local: snapshot)
    comparison = matcher.call(local: snapshot, results: search.fetch(:results))
    unless search.fetch(:complete)
      comparison[:status] = 'needs_review'
      comparison[:reason] = 'Recherche incomplète au-delà de la borne de pagination : aucune identité retenue.'
    end
    movie = comparison[:status] == 'candidate' ? client.movie(id: comparison.fetch(:tmdb_id)) : nil
    if movie
      detailed = matcher.call(local: snapshot, results: [movie])
      comparison = detailed unless detailed[:status] == 'candidate'
    end
    if movie && comparison[:status] == 'candidate'
      movie = release_reference.call(movie: movie, release_dates: client.release_dates(id: movie.fetch('id')))
      proposal = proposer.call(local: snapshot, movie: movie, known_genres: known)
    else
      proposal = nil
    end
    row = { policy: 'film_metadata_proposal_v2', status: proposal ? 'candidate' : 'needs_review', local: snapshot,
            copy_ids: copies.map { |copy| copy.fetch('asset_id') }.sort, comparison: comparison, proposal: proposal,
            search_complete: search.fetch(:complete), search_queries: search.fetch(:queries), execution_authorized: false,
            database_changed: false, video_files_changed: false, prepared_at: Time.current.iso8601 }
    temporary = path.sub_ext('.tmp')
    temporary.write(JSON.pretty_generate(row))
    File.rename(temporary, path)
    results << row.stringify_keys
    warn "Catalogue films : #{index + 1}/#{groups.size} fiches examinées" if ((index + 1) % 50).zero?
  end
  report = { format: 'vidb.film_metadata_proposals', version: 1, policy: 'film_metadata_proposal_v2',
             source_generated_at: input['generated_at'], records: results, total: results.size,
             counts: results.group_by { |row| row.fetch('status') }.transform_values(&:size),
             execution_authorized: false, database_changed: false, video_files_changed: false,
             attribution: 'Données TMDB ; cette intégration n’est ni approuvée ni certifiée par TMDB.' }
  output = directory.join('report.json')
  temporary = output.sub_ext('.tmp')
  temporary.write(JSON.pretty_generate(report))
  File.rename(temporary, output)
  puts JSON.pretty_generate(output: output.to_s, total: report[:total], counts: report[:counts], execution_authorized: false)
rescue StandardError => e
  # Do not echo authenticated URLs, credentials or transport payloads.
  warn JSON.pretty_generate(status: 'stopped', error_class: e.class.name,
                            error: e.is_a?(CatalogEnrichment::TmdbClient::Error) ? e.message : 'Preparation interrupted; completed per-record proposals remain cached.',
                            record_id: current_record_id,
                            database_changed: false, video_files_changed: false)
  exit 1
ensure
  lock&.close
end
