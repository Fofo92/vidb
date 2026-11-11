# frozen_string_literal: true

# bin/rails runner script/fetch_record_posters.rb [--apply] [RECORD_ID ...]
apply = ARGV.delete('--apply')
raise ArgumentError, 'Usage: script/fetch_record_posters.rb [--apply] [RECORD_ID ...]' unless ARGV.all? { |id| id.match?(/\A[1-9]\d*\z/) }

scope = Record.where(record_kind: %w[series season standalone_video collection undetermined])
scope = scope.where(id: ARGV.map(&:to_i)) if ARGV.any?
counts = Hash.new(0)
unidentified = []
fetcher = RecordPosters::Fetch.new if apply
File.open(Rails.root.join('tmp/poster-import.lock'), File::RDWR | File::CREAT, 0o600) do |lock|
  abort 'Un import de pochettes est déjà en cours.' unless lock.flock(File::LOCK_EX | File::LOCK_NB)

  scope.find_each do |record|
    poster = record.record_poster
    if RecordPosters::Fetch.preserved?(poster)
      counts[:preserved] += 1
      next
    end
    if apply
      status = fetcher.call(record)
      counts[status] += 1
      unidentified << record.id if status == :unidentified
    elsif RecordPosters::Target.call(record)
      counts[:ready] += 1
    else
      searchable = RecordPosters::FilmTarget.searchable?(record) || RecordPosters::SeriesTarget.searchable?(record)
      counts[searchable ? :to_identify : :unidentified] += 1
    end
  rescue RecordPosters::Fetch::Error, RecordPosters::ImageDownload::Error,
         RecordPosters::Store::Error, CatalogEnrichment::TmdbClient::Error, ActiveRecord::ActiveRecordError,
         ArgumentError, KeyError, JSON::ParserError, IOError, SystemCallError, SocketError,
         Timeout::Error, OpenSSL::SSL::SSLError => e
    counts[:errors] += 1
    warn "#{record.id} | #{e.message}"
  end
end
puts JSON.pretty_generate(applied: !!apply, counts: counts, unidentified_record_ids: unidentified)
