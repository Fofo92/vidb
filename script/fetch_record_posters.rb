# frozen_string_literal: true

# bin/rails runner script/fetch_record_posters.rb [--apply] [RECORD_ID ...]
apply = ARGV.delete('--apply')
raise ArgumentError, 'Usage: script/fetch_record_posters.rb [--apply] [RECORD_ID ...]' unless ARGV.all? { |id| id.match?(/\A[1-9]\d*\z/) }

scope = Record.where(record_kind: %w[series season standalone_video collection])
scope = scope.where(id: ARGV.map(&:to_i)) if ARGV.any?
counts = Hash.new(0)
fetcher = RecordPosters::Fetch.new if apply
scope.find_each do |record|
  poster = record.record_poster
  if poster && (poster.image.attached? || poster.source['kind'] == 'manual')
    counts[:preserved] += 1
    next
  end
  unless RecordPosters::Target.call(record)
    counts[:unidentified] += 1
    next
  end

  counts[apply ? fetcher.call(record) : :ready] += 1
rescue RecordPosters::Fetch::Error, RecordPosters::ImageDownload::Error,
       RecordPosters::Store::Error, CatalogEnrichment::TmdbClient::Error, ActiveRecord::RecordInvalid => e
  counts[:errors] += 1
  warn "#{record.id} | #{e.message}"
end
puts JSON.pretty_generate(applied: !!apply, counts: counts)
