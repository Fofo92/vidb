# frozen_string_literal: true

module CatalogEnrichment
  # One transactional work update at a time; journals allow safe batch resumption.
  class FilmMetadataApplication
    def initialize(journal_directory:, operation:)
      @journal = FilmMetadataJournal.new(directory: journal_directory)
      @operation = operation
      @changes = FilmMetadataChanges.new
    end

    def call(entry:, apply: false)
      validate_request!(apply)
      result = Record.transaction do
        readonly_preview! unless apply
        locked_result(entry, apply)
      end
      finish(result) if apply && %w[applied already_applied protected_after_enrichment].include?(result[:status])
      result
    end

    private

    def readonly_preview!
      return unless Record.connection.adapter_name == 'PostgreSQL'

      Record.connection.execute('SET TRANSACTION ISOLATION LEVEL REPEATABLE READ, READ ONLY')
    end

    def validate_request!(apply)
      raise ArgumentError, 'Boolean apply flag required' unless [true, false].include?(apply)
      raise ArgumentError, 'Outer transaction prevents commit verification' if Record.connection.transaction_open?
    end

    def locked_result(entry, apply)
      record = (apply ? Record.lock : Record).find(entry.fetch('local').fetch('record_id'))
      completed = previous_result(record, @journal.rows(record.id))
      return completed if completed

      change = @changes.call(record: record, entry: entry, operation: @operation)
      return change.merge(record_id: record.id) unless apply && change[:status] == 'ready'

      write(record, entry, change)
    end

    def previous_result(record, rows)
      return if rows.empty?
      unless rows.all? { |row| row['record_id'] == record.id && row['operation_id'] == @operation }
        return { status: 'protected_previous_operation', record_id: record.id }
      end

      return committed_result(record, rows) if marker?(record)
      return unless rows.any? { |row| row['event'] == 'completed' }

      { status: 'protected_previous_operation', record_id: record.id }
    end

    def marker?(record)
      proofs = [record.year_evidence] + record.year_history.map { |row| row['evidence'] }
      proofs.any? { |proof| proof.is_a?(Hash) && proof['operation_id'] == @operation }
    end

    def committed_result(record, rows)
      prepared = rows.rfind { |row| row['event'] == 'prepared' }
      raise ArgumentError, 'Prepared journal evidence missing' unless prepared

      matches = target_matches?(record, prepared.fetch('target'))
      { status: matches ? 'already_applied' : 'protected_after_enrichment', record_id: record.id }
    end

    def target_matches?(record, target)
      record.year == target['year'] && record.year_basis == target['year_basis'] &&
        record.genders.reload.map(&:name).sort == target['genres'].sort
    end

    def write(record, entry, change)
      before = record.attributes.deep_dup
      genres_before = record.gender_ids.sort
      @journal.append(record.id, @operation, 'prepared',
                      local: entry.fetch('local'), target: change.fetch(:target),
                      source: entry.fetch('proposal').fetch('source'))
      persist(record, change)
      verify_preserved!(record, before)
      { status: 'applied', record_id: record.id, year: record.year,
        year_value_changed: before['year'] != record.year, genres_added: record.gender_ids.sort != genres_before,
        genre_review_required: change[:genre_review_required], journal_path: @journal.path(record.id).to_s }
    end

    def persist(record, change)
      record.assign_attributes(change.fetch(:attributes))
      persist_genres(record, change) if change[:gender_ids]
      record.save!
    end

    def persist_genres(record, change)
      raise ArgumentError, 'Protected genre provenance' if record.genre_provenance.present?

      record.with_reviewed_genre_assignment { record.gender_ids = change.fetch(:gender_ids) }
      record.genre_provenance = {
        'origin' => 'initial_external_enrichment', 'protected' => true, 'operation_id' => @operation,
        'genres' => record.genders.map(&:name).sort, 'previous_genres' => [],
        'evidence' => record.year_evidence.deep_dup, 'recorded_at' => Time.current.iso8601
      }
    end

    def verify_preserved!(record, before)
      permitted = %w[year year_basis year_evidence year_history updated_at genre_provenance]
      return if record.reload.attributes.except(*permitted) == before.except(*permitted)

      raise ArgumentError, 'Unrelated record attributes changed'
    end

    def finish(result)
      id = result.fetch(:record_id)
      rows = @journal.rows(id)
      @journal.append(id, @operation, 'completed') unless rows.last&.fetch('event') == 'completed'
    end
  end
end
