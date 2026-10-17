module VideoAssets
  # Only a complete inventory of the mounted volume can establish an absence.
  class DiskPresence
    def initialize(root: '/videos', guard: ReconciliationVolumeGuard.new(root: '/videos'))
      @root = root
      @guard = guard
    end

    def call(inventory)
      source = inventory.deep_symbolize_keys
      validate!(source)
      @entries = source.fetch(:entries).index_by { |entry| entry.fetch(:path) }
      @guard.call
      VideoAsset.transaction do
        lock_tables!
        counts = synchronize
        @guard.call
        counts
      end
    end

    private

    def validate!(source)
      valid = source[:roots] == [@root] && source[:generated_at].present?
      valid &&= source[:format] == 'vidb.video_library_inventory' && source[:version] == 1
      valid &&= source.fetch(:entries).none? { |entry| %w[missing_root inaccessible].include?(entry[:type]) }
      raise ArgumentError, 'Scan incomplet : présence des copies inchangée' unless valid
    end

    def lock_tables!
      connection = VideoAsset.connection
      return unless connection.adapter_name == 'PostgreSQL'

      connection.execute('LOCK TABLE records IN SHARE ROW EXCLUSIVE MODE')
      connection.execute('LOCK TABLE video_assets IN SHARE ROW EXCLUSIVE MODE')
    end

    def synchronize
      counts = { 'missing' => 0, 'restored' => 0 }
      VideoAsset.where(status: %w[present missing]).order(:id).lock.each do |asset|
        path = asset.last_known_path
        next unless path&.start_with?("#{@root}/") && Pathname.new(path).cleanpath.to_s == path

        target = target_status(asset)
        next unless target && target != asset.status

        transition(asset, target)
        counts[target == 'missing' ? 'missing' : 'restored'] += 1
      end
      counts
    end

    def target_status(asset)
      path = asset.last_known_path
      stat = stat_or_absent(path)
      entry = @entries[path]
      raise ArgumentError, "Disque modifié pendant le scan : #{path}" if entry.nil? != stat.nil?
      return 'missing' unless stat
      return unless matching_entry?(path, entry, stat)
      return unless asset.byte_size == stat.size && asset.observed_at && asset.observed_at >= stat.mtime

      'present'
    end

    def stat_or_absent(path)
      File.lstat(path)
    rescue Errno::ENOENT, Errno::ENOTDIR
      nil
    end

    def matching_entry?(path, entry, stat)
      valid = stat.file? && entry[:type] == 'file' && File.realpath(path) == path
      valid &&= stat.size == entry[:size] && stat.mtime.to_i == Time.iso8601(entry.fetch(:modified_at)).to_i
      raise ArgumentError, "Copie modifiée pendant le scan : #{path}" unless valid

      true
    end

    def transition(asset, target)
      history = asset.technical_details.fetch('disk_presence_history', [])
      event = { 'from' => asset.status, 'to' => target, 'checked_at' => Time.current.iso8601(9),
                'origin' => 'complete_disk_scan' }
      asset.update!(status: target,
                    technical_details: asset.technical_details.merge('disk_presence_history' => history + [event]))
    end
  end
end
