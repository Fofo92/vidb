# frozen_string_literal: true

require 'json'
require 'securerandom'
require 'time'

module VideoAssets
  # Trial-only coordination of filesystem rename and Active Record update.
  # A journal is synced before the rename. Errors require inspection, never
  # automatic reversal: PostgreSQL and the filesystem cannot commit together.
  class RelocationTrialCommit
    class Refused < StandardError; end

    class Failed < StandardError
      attr_reader :journal_path

      def initialize(journal_path)
        @journal_path = journal_path
        super("Trial relocation requires inspection; journal: #{journal_path}")
      end
    end

    def initialize(root:, planner:, writer: nil)
      @directory = RelocationTrialDirectory.new(root, error: Refused)
      @root = @directory.root
      @planner = planner
      @writer = writer || ->(asset, target) { asset.update!(last_known_path: target) }
    end

    def call(plan:, asset:, genres:)
      validate_trial!(asset)
      raise Refused, 'Initial preview is not ready' unless plan[:ready] == true

      with_journal do |journal|
        commit(journal, plan, asset, genres)
        { status: :completed, journal_path: journal.path, database_updated: true }
      end
    end

    private

    def with_journal(&)
      path = @root.join("relocation-#{SecureRandom.uuid}.jsonl").to_s
      flags = File::WRONLY | File::CREAT | File::EXCL | File::NOFOLLOW
      File.open(path, flags, 0o600, &)
    end

    def commit(journal, plan, asset, genres)
      asset.record.with_lock do
        asset.with_lock { execute_locked(journal, plan, asset, genres) }
      end
      RelocationTrialJournalIo.append(journal, 'completed')
    rescue StandardError => e
      RelocationTrialJournalIo.record_failure(journal, 'needs_review', e)
      raise Failed.new(journal.path), cause: e
    end

    def execute_locked(journal, plan, asset, genres)
      current = checked_preview(plan, asset, genres)
      details = current.slice(:asset_id, :record_id, :source, :target, :identity)
      RelocationTrialJournalIo.append(journal, 'prepared', details)
      File.open(@root, File::RDONLY | File::NOFOLLOW, &:fsync)
      executor = RelocationTrialExecutor.new(root: @root, planner: @planner)
      executor.call(plan: current, asset: asset, genres: genres)
      RelocationTrialJournalIo.append(journal, 'filesystem_renamed')
      @writer.call(asset, current.fetch(:target))
    end

    def checked_preview(plan, asset, genres)
      raise Refused, 'Asset is no longer present' unless asset.status_present?

      current = @planner.recheck(plan: plan, asset: asset, genres: genres)
      raise Refused, 'Preview no longer matches' unless current[:ready] == true

      validate_destination!(current, asset)
      current
    end

    def validate_destination!(current, asset)
      unless [current[:source], current[:target]].all? { |path| @directory.direct_path?(Pathname.new(path)) }
        raise Refused, 'Only files directly inside the trial root are allowed'
      end

      occupied = asset.class.where(status: 'present', last_known_path: current.fetch(:target))
                      .where.not(id: asset.id).exists?
      raise Refused, 'Destination already belongs to another present asset' if occupied
    end

    def validate_trial!(asset)
      raise Refused, 'Database coordination is restricted to the Rails test environment' unless Rails.env.test?

      @directory.validate!
      raise Refused, 'A persisted, unchanged asset is required' unless asset.persisted? && !asset.has_changes_to_save?
      raise Refused, 'An outer transaction prevents commit verification' if asset.class.connection.transaction_open?
    end
  end
end
