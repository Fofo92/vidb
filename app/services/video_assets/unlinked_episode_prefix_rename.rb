module VideoAssets
  class UnlinkedEpisodePrefixRename
    def initialize(root:, directory:, series_title:, journal_path:, adapters: {})
      @root = Pathname.new(root).cleanpath
      @directory = Pathname.new(directory).cleanpath
      @series_title = series_title
      @journal_path = journal_path
      @guard = adapters.fetch(:guard) { ReconciliationVolumeGuard.new(root: root) }
      @renamer = adapters.fetch(:renamer) { RelocationFileRename.new }
    end

    def call(apply: false)
      @guard.call
      return planner.call.merge('execution_authorized' => false) unless apply

      EpisodePrefixJournal.new(@journal_path).open { |journal| execute(journal) }
    end

    private

    def planner
      EpisodePrefixPlan.new(root: @root, directory: @directory, series_title: @series_title)
    end

    def execute(journal)
      plan = journal.prepare { planner.call }
      validate_scope!(plan)
      renamed = plan.fetch('operations').count { |operation| execute_one(journal, operation) }
      { 'status' => 'completed', 'total' => plan.fetch('operations').size, 'renamed_this_run' => renamed,
        'journal_path' => @journal_path.to_s, 'database_updated' => false }
    end

    def validate_scope!(plan)
      return if plan.values_at('format', 'version', 'directory', 'series_title') ==
                ['vidb.unlinked_episode_prefix_rename', 1, @directory.to_s, @series_title]

      raise ArgumentError, 'Le journal appartient à un autre périmètre'
    end

    def execute_one(journal, operation)
      @guard.call
      validate_paths!(operation)
      return verify_target!(operation) && false if journal.completed?(operation.fetch('source'))

      renamed = locked_rename(operation)
      journal.append('completed', operation.slice('source', 'target'))
      renamed
    end

    def locked_rename(operation)
      VideoAsset.transaction do
        lock_assets!
        source = operation.fetch('source')
        refuse_assets!([source])
        return verify_target!(operation) && false unless File.exist?(source) || File.symlink?(source)

        refuse_assets!([operation.fetch('target')])
        @renamer.call(source: source, target: operation.fetch('target'),
                      identity: operation.fetch('identity').symbolize_keys)
        true
      end
    end

    def lock_assets!
      return unless VideoAsset.connection.adapter_name == 'PostgreSQL'

      VideoAsset.connection.execute('LOCK TABLE video_assets IN SHARE ROW EXCLUSIVE MODE')
    end

    def refuse_assets!(paths)
      return unless VideoAsset.where(last_known_path: paths).where.not(status: 'deleted').exists?

      raise ArgumentError, 'Une copie suivie est apparue : renommage suspendu avant toute modification de cette copie'
    end

    def validate_paths!(operation)
      source, target = operation.values_at('source', 'target').map { |path| Pathname.new(path) }
      valid = [source, target].all? { |path| canonical_scoped?(path) }
      return if valid && source.dirname == target.dirname && source != target

      raise ArgumentError, 'Chemins du journal hors du périmètre autorisé'
    end

    def canonical_scoped?(path)
      path.absolute? && path == path.cleanpath && path.to_s.start_with?("#{@directory}/") &&
        path.dirname.realpath == path.dirname
    end

    def verify_target!(operation)
      source, target = operation.values_at('source', 'target')
      stat = File.lstat(target)
      actual = RelocationFileIdentity.call(stat).stringify_keys.except('ctime_ns')
      valid = stat.file? && !File.exist?(source) && !File.symlink?(source) &&
              actual == operation.fetch('identity').except('ctime_ns')
      raise ArgumentError, 'État du renommage différent du journal' unless valid

      stat
    end
  end
end
