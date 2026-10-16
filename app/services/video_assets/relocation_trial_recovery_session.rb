# frozen_string_literal: true

module VideoAssets
  class RelocationTrialRecoverySession
    def self.validate_state!(diagnostic)
      return if %i[database_update_pending consistent_target].include?(diagnostic[:status])

      raise RelocationTrialRecovery::Refused, "Recovery refused: #{diagnostic[:status]}"
    end

    def initialize(inspector, writer, journal, path, prepared)
      @inspector = inspector
      @writer = writer
      @journal = journal
      @path = path
      @prepared = prepared
      @started = false
    end

    def call
      asset = VideoAsset.find_by(id: @prepared.fetch('asset_id'))
      raise RelocationTrialRecovery::Refused, 'Asset no longer exists' unless asset

      asset.record.with_lock { asset.with_lock { update_locked(asset) } }
      complete_result
    rescue StandardError => e
      raise unless @started

      RelocationTrialJournalIo.record_failure(@journal, 'database_recovery_failed', e)
      raise RelocationTrialRecovery::Failed.new(@path), cause: e
    end

    private

    def update_locked(asset)
      current = inspect_locked
      self.class.validate_state!(current)
      return unless current[:status] == :database_update_pending

      start_attempt(current)
      @writer.call(asset, @prepared.fetch('target'))
      return if inspect_locked[:status] == :consistent_target

      raise RelocationTrialRecovery::Refused, 'State changed during database recovery'
    end

    def start_attempt(current)
      @started = true
      if current[:last_event] == 'database_recovery_started'
        details = { error_class: 'InterruptedAttempt',
                    error_message: 'Prior attempt ended without a completion event' }
        RelocationTrialJournalIo.append(@journal, 'database_recovery_failed', details)
      end
      RelocationTrialJournalIo.append(@journal, 'database_recovery_started')
    end

    def complete_result
      RelocationTrialJournalIo.append(@journal, 'database_recovery_completed') if @started
      { status: @started ? :recovered : :already_consistent, journal_path: @path.to_s,
        database_updated: @started, files_changed: false }
    end

    def inspect_locked
      before = RelocationFileIdentity.signature(@journal.stat)
      current = @inspector.call(journal_path: @path)
      raise RelocationTrialRecovery::Refused, 'Journal changed during inspection' unless unchanged_journal?(before)
      raise RelocationTrialRecovery::Refused, 'Prepared plan changed' unless current[:prepared] == @prepared

      current
    end

    def unchanged_journal?(before)
      visible = File.lstat(@path)
      stat = @journal.stat
      before == RelocationFileIdentity.signature(stat) && visible.file? &&
        [visible.dev, visible.ino] == [stat.dev, stat.ino]
    end
  end
end
