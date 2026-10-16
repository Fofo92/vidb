# frozen_string_literal: true

require 'json'

module VideoAssets
  # Read-only diagnostic; observations are not an atomic snapshot.
  # Target metadata excludes ctime changed by rename; it does not prove byte equality.
  class RelocationTrialInspection
    class Refused < StandardError; end

    class InvalidJournal < StandardError; end

    def initialize(root:, assets: VideoAsset)
      @directory = RelocationTrialDirectory.new(root, error: Refused)
      @assets = assets
      @format = RelocationTrialJournalFormat.new(@directory, error: InvalidJournal)
      @reader = RelocationTrialJournalReader.new(@format, error: InvalidJournal)
      @observer = RelocationFileObservation.new
    end

    def call(journal_path:)
      @directory.validate!
      result_for(validated_path(journal_path))
    rescue InvalidJournal, JSON::ParserError => e
      { status: :invalid_journal, automatic_action: false, reason: e.message }
    end

    private

    def validated_path(journal_path)
      path = Pathname.new(journal_path)
      return path if @directory.direct_path?(path) && path.extname == '.jsonl'

      raise Refused, 'Journal must be directly inside the trial directory'
    end

    def result_for(path)
      events = @reader.call(path)
      prepared = events.find { |entry| entry['event'] == 'prepared' }
      return report(:unprepared, path, events) unless prepared

      @format.validate_prepared!(prepared)
      observations = observations_for(prepared)
      state = RelocationTrialState.new(prepared, observations).call
      report(state, path, events).merge(prepared: prepared, **observations)
    end

    def observations_for(prepared)
      expected = prepared.fetch('identity')
      { source: @observer.call(prepared.fetch('source'), expected, renamed: false),
        target: @observer.call(prepared.fetch('target'), expected, renamed: true),
        database: database_state(prepared.fetch('asset_id')),
        target_claimed_by_other_asset: target_claimed?(prepared) }
    end

    def database_state(id)
      asset = @assets.find_by(id: id)
      return unless asset

      { asset_id: asset.id, record_id: asset.record_id, status: asset.status, path: asset.last_known_path }
    end

    def target_claimed?(prepared)
      @assets.where(status: 'present', last_known_path: prepared.fetch('target'))
             .where.not(id: prepared.fetch('asset_id')).exists?
    end

    def report(status, path, events)
      { status: status, journal_path: path.to_s, last_event: events.last.fetch('event'), automatic_action: false }
    end
  end
end
