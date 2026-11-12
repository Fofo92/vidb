# frozen_string_literal: true

# Read-only catalogue diagnostic. API responses may populate the existing cache.
# Usage: bin/rails runner script/diagnose_series_poster.rb RECORD_ID
# Also accepts VIDB_POSTER_RECORD_ID when the script is supplied on STDIN.
class SeriesPosterDiagnosticClient
  attr_reader :responses

  def initialize
    @client = EncoderProjects::TmdbSeriesClient.new(
      cache_dir: Rails.root.join('tmp/poster-series-cache'), max_age: 6.hours
    )
    @responses = []
  end

  def search(title:, page: 1)
    result = @client.search(title: title, page: page)
    @responses << {
      operation: 'search', query: title,
      pagination: result.slice('page', 'total_pages', 'total_results'),
      candidates: result.fetch('results').map do |row|
        row.slice('id', 'name', 'original_name', 'first_air_date', 'poster_path')
      end
    }
    result
  end

  def get(path, language: 'fr-FR')
    result = @client.get(path, language: language)
    entry = { operation: 'get', path: path, language: language,
              metadata: result.slice('id', 'name', 'original_name', 'original_language',
                                     'first_air_date', 'poster_path', 'season_number') }
    if result['episodes'].is_a?(Array)
      entry[:episodes] = result['episodes'].map do |row|
        row.slice('id', 'episode_number', 'season_number', 'name', 'air_date')
      end
    end
    @responses << entry
    result
  end
end

id = ARGV.shift || ENV.fetch('VIDB_POSTER_RECORD_ID')
raise ArgumentError, 'Usage: diagnose_series_poster.rb RECORD_ID' unless ARGV.empty? && id.match?(/\A[1-9]\d*\z/)

client = SeriesPosterDiagnosticClient.new
report = nil
Record.transaction do
  raise 'PostgreSQL requis pour le diagnostic en lecture seule' unless Record.connection.adapter_name == 'PostgreSQL'

  Record.connection.execute('SET TRANSACTION ISOLATION LEVEL REPEATABLE READ, READ ONLY')
  record = Record.find(id)
  raise 'La fiche doit être une série' unless record.record_kind == 'series'

  poster = record.record_poster
  report = {
    record_id: record.id, title: record.complete_title,
    existing_target: RecordPosters::Target.call(record),
    stored_identity_ids: RecordPosters::Target.series_ids(record),
    poster_source: poster&.source,
    poster_attached: poster&.image&.attached? || false,
    automatic_policy_preserves_poster: RecordPosters::Fetch.preserved?(poster),
    searchable: RecordPosters::SeriesTarget.searchable?(record),
    local_catalogue: record.subtree.order(:ancestry, :rank, :id).map do |row|
      row.attributes.slice('id', 'ancestry', 'record_kind', 'rank', 'french_title', 'original_title', 'year')
    end
  }
  begin
    report[:automatic_target] = report[:existing_target] || RecordPosters::SeriesTarget.new(client: client).call(record)
  rescue CatalogEnrichment::TmdbClient::Error, ArgumentError, KeyError, JSON::ParserError,
         IOError, SystemCallError, SocketError => e
    report[:error] = { type: e.class.name, message: e.message }
  end
  report[:tmdb_responses] = client.responses
end
puts JSON.pretty_generate(report)
