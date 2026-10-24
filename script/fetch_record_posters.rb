# frozen_string_literal: true

# bin/rails runner script/fetch_record_posters.rb [--apply] [RECORD_ID ...]
apply = ARGV.delete('--apply')
raise ArgumentError, 'Usage: script/fetch_record_posters.rb [--apply] [RECORD_ID ...]' unless ARGV.all? { |id| id.match?(/\A[1-9]\d*\z/) }

scope = Record.where(record_kind: %w[series season standalone_video collection undetermined])
scope = scope.where(id: ARGV.map(&:to_i)) if ARGV.any?
counts = Hash.new(0)
fetcher = RecordPosters::Fetch.new if apply
File.open(Rails.root.join('tmp/poster-import.lock'), File::RDWR | File::CREAT, 0o600) do |lock|
  abort 'Un import de pochettes est déjà en cours.' unless lock.flock(File::LOCK_EX | File::LOCK_NB)

  scope.find_each do |record|
    poster = record.record_poster
    if poster && (poster.image.attached? || poster.source['kind'] == 'manual')
      counts[:preserved] += 1
      next
    end
    if apply
      counts[fetcher.call(record)] += 1
    elsif RecordPosters::Target.call(record)
      counts[:ready] += 1
    else
      counts[RecordPosters::FilmTarget.searchable?(record) ? :to_identify : :unidentified] += 1
    end
  rescue RecordPosters::Fetch::Error, RecordPosters::ImageDownload::Error,
         RecordPosters::Store::Error, CatalogEnrichment::TmdbClient::Error, ActiveRecord::RecordInvalid => e
    counts[:errors] += 1
    warn "#{record.id} | #{e.message}"
  end
end
puts JSON.pretty_generate(applied: !!apply, counts: counts)
