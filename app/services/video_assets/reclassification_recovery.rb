# frozen_string_literal: true

module VideoAssets
  class ReclassificationRecovery < ReclassificationCommit
    def initialize(**options)
      @checkpoint = ReclassificationCheckpoint.new(options.fetch(:journal_directory))
      super
    end

    def preview_state(plan:, asset:, genres:)
      @volume_guard.call
      @checkpoint.open(asset) { |_file, rows| checkpoint_state(plan, asset, genres, rows) }
    end

    def call(plan:, asset:, genres:, authorized: false)
      validate_request!(plan, asset, authorized)
      @volume_guard.call
      @checkpoint.open(asset, writable: true) do |file, rows|
        recover_locked(file, rows, plan, asset, genres)
      end
    end

    private

    def recover_locked(file, rows, plan, asset, genres)
      asset.record.with_lock do
        asset.with_lock { resume_sql_or_files(file, rows, plan, asset, genres) }
      end
      RelocationJournal.append(file, 'reconciled') unless %w[completed reconciled].include?(rows.last&.fetch('event'))
      { status: :reconciled, journal_path: file.path, source: plan[:source], target: plan[:target] }
    rescue StandardError => e
      RelocationJournal.failure(file, e)
      raise Failed.new(file.path), cause: e
    end

    def resume_sql_or_files(file, rows, plan, asset, genres)
      case checkpoint_state(plan, asset, genres, rows)
      when :before_rename then resume_before_rename(file, rows, plan, asset, genres)
      when :filesystem_done
        moved = rows.any? { |row| row['event'] == 'filesystem_renamed' }
        record_physical_checkpoint(file, plan) unless moved
        @writer.call(asset, plan.fetch(:target))
      when :database_done then nil
      else raise Refused, 'Unknown recovery state'
      end
    end

    def resume_before_rename(file, rows, plan, asset, genres)
      return execute_locked(file, plan, asset, genres) unless rows.any? { |row| row['event'] == 'prepared' }

      current = checked_preview(plan, asset, genres)
      rename_and_verify!(file, current)
      @writer.call(asset, current.fetch(:target))
    end

    def checkpoint_state(plan, asset, genres, rows)
      @classification = classification_for(asset.record)
      payload = plan.slice(:record_id, :asset_id, :source, :target, :identity)
                    .merge(classification: @classification, qualification: @qualification)
      @checkpoint.validate_rows!(rows, payload)
      if File.exist?(plan[:source]) || File.symlink?(plan[:source])
        return before_rename_state(plan, asset, genres,
                                   rows)
      end

      after_rename_state(plan, asset, rows)
    end

    def after_rename_state(plan, asset, rows)
      raise Refused, 'No prepared evidence for a moved file' unless rows.any? { |row| row['event'] == 'prepared' }

      validate_moved_file!(plan, asset)
      verify_after_identity!(plan, rows)
      moved_state(plan, asset)
    end

    def before_rename_state(plan, asset, genres, rows)
      unless (rows.map { |row| row['event'] } - %w[prepared needs_review]).empty?
        raise Refused, 'Source reappeared after a recorded move'
      end

      checked_preview(plan, asset, genres)
      :before_rename
    end

    def validate_moved_file!(plan, asset)
      raise Refused, 'Classification target changed' unless @classification[:target] == plan[:target]

      paths = %i[source target].map { |key| Pathname.new(plan.fetch(key)) }
      raise Refused, 'Symlink or missing ancestor' unless paths.all? { |path| safe_ancestors?(path) }

      validate_paths!(plan, asset)
      verify_rename!(plan)
    end

    def safe_ancestors?(path)
      directory = path.dirname
      loop do
        return false unless File.lstat(directory).directory?
        return true if directory.root?

        directory = directory.parent
      end
    end

    def moved_state(plan, asset)
      if asset.last_known_path == plan[:source]
        verify_snapshots!(asset)
        return :filesystem_done
      end
      raise Refused, 'Unexpected SQL path' unless asset.last_known_path == plan[:target]

      verify_preserved_metadata!(asset)
      ReclassificationReceipt.verify!(record: asset.record, qualification: @qualification,
                                      classification: @classification)
      :database_done
    end

    def verify_after_identity!(plan, rows)
      moved = rows.find { |row| row['event'] == 'filesystem_renamed' }
      return unless moved

      actual = RelocationFileIdentity.call(File.lstat(plan.fetch(:target))).as_json
      raise Refused, 'Target changed since physical checkpoint' unless moved['identity_after'] == actual
    end
  end
end
