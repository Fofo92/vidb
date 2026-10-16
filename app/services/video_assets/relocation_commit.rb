# frozen_string_literal: true

module VideoAssets
  # Explicit commit only. A failure is journalled; no automatic inverse move occurs.
  class RelocationCommit
    class Refused < StandardError; end

    class Failed < StandardError
      attr_reader :journal_path

      def initialize(path)
        @journal_path = path.to_s
        super("Relocation requires inspection; journal: #{path}")
      end
    end

    def initialize(root:, planner:, journal_directory:, volume_guard:, writer: nil)
      @root = Pathname.new(root).cleanpath
      @planner = planner
      @journal = RelocationJournal.new(journal_directory)
      @volume_guard = volume_guard
      @renamer = RelocationFileRename.new
      @writer = writer || ->(asset, target) { asset.update!(last_known_path: target) }
    end

    def call(plan:, asset:, genres:, authorized: false)
      validate_request!(plan, asset, authorized)
      @volume_guard.call
      @journal.open(asset) do |journal|
        commit(journal, plan, asset, genres)
        { status: :completed, journal_path: journal.path, database_updated: true, source: plan[:source],
          target: plan[:target] }
      end
    end

    private

    def validate_request!(plan, asset, authorized)
      raise Refused, 'Explicit execution authorization is required' unless authorized == true
      raise Refused, 'Initial preview is not ready' unless plan[:ready] == true
      raise Refused, 'A persisted unchanged asset is required' unless asset.persisted? && !asset.has_changes_to_save?
      raise Refused, 'An outer transaction prevents commit verification' if asset.class.connection.transaction_open?
    end

    def commit(journal, plan, asset, genres)
      asset.record.with_lock { asset.with_lock { execute_locked(journal, plan, asset, genres) } }
      RelocationJournal.append(journal, 'completed')
    rescue StandardError => e
      RelocationJournal.failure(journal, e)
      raise Failed.new(journal.path), cause: e
    end

    def execute_locked(journal, plan, asset, genres)
      current = checked_preview(plan, asset, genres)
      RelocationJournal.append(journal, 'prepared', current.slice(:record_id, :asset_id, :source, :target, :identity))
      @renamer.call(source: current.fetch(:source), target: current.fetch(:target), identity: current.fetch(:identity))
      RelocationJournal.append(journal, 'filesystem_renamed')
      @writer.call(asset, current.fetch(:target))
    end

    def checked_preview(plan, asset, genres)
      @volume_guard.call
      raise Refused, 'Asset is no longer present' unless asset.status_present?
      raise Refused, 'Genres changed since preview' unless asset.record.genders.reload.map(&:name).sort == genres.sort

      current = @planner.recheck(plan: plan, asset: asset, genres: genres)
      raise Refused, 'Preview no longer matches' unless current[:ready] == true

      validate_paths!(current, asset)
      current
    end

    def validate_paths!(current, asset)
      paths = %i[source target].map { |key| Pathname.new(current.fetch(key)) }
      valid = @root.absolute? && paths.all? { |path| inside_root?(path) }
      unless valid && paths.first.dirname == paths.last.dirname
        raise Refused, 'Paths must stay inside the expected root and directory'
      end

      occupied = asset.class.where(status: 'present', last_known_path: current.fetch(:target))
                      .where.not(id: asset.id).exists?
      raise Refused, 'Destination belongs to another present copy' if occupied
    end

    def inside_root?(path)
      path.absolute? && path == path.cleanpath && path.to_s.start_with?("#{@root}/")
    end
  end
end
