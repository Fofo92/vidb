# frozen_string_literal: true

# Preview may populate the API cache, but never changes catalogue or poster records.
apply = ARGV.delete('--apply')
refresh = ARGV.delete('--refresh')
raise ArgumentError, 'Usage: [--apply] [--refresh] [RECORD_ID ...]' unless ARGV.all? { |id| id.match?(/\A[1-9]\d*\z/) }

scope = Record.where(record_kind: 'collection')
scope = scope.where(id: ARGV.map(&:to_i)) if ARGV.any?
client = RecordPosters::CollectionClient.new(cache_dir: Rails.root.join('tmp/poster-collection-cache'), refresh: !!refresh)
planner = RecordPosters::CollectionPlan.new(client: client)
importer = RecordPosters::CollectionImport.new(client: client, fetcher: RecordPosters::Fetch.new(client: client)) if apply
counts = Hash.new(0)
puts JSON.generate(type: 'mode', applied: !!apply)
File.open(Rails.root.join('tmp/poster-import.lock'), File::RDWR | File::CREAT, 0o600) do |lock|
  abort 'Un import de pochettes est déjà en cours.' unless lock.flock(File::LOCK_EX | File::LOCK_NB)

  scope.find_each do |record|
    plan = planner.call(record)
    result = apply ? importer.call(record, expected: plan) : plan
    counts[result.fetch(:status)] += 1
    puts JSON.generate(result.merge(fiche: record.id, titre: record.french_title))
  rescue StandardError => error
    counts['errors'] += 1
    puts JSON.generate(fiche: record.id, status: 'error', error: error.message)
  end
end
puts JSON.generate(type: 'summary', applied: !!apply, counts: counts)
