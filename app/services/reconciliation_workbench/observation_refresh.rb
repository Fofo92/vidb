module ReconciliationWorkbench
  class ObservationRefresh
    def call
      require Rails.root.join('script/video_library_inventory').to_s
      directory = Planner.followup_path.dirname
      directory.mkpath
      File.open(directory.join('refresh.lock'), File::RDWR | File::CREAT, 0o600) do |lock|
        unless lock.flock(File::LOCK_EX | File::LOCK_NB)
          raise ArgumentError,
                'Un scan est déjà en cours ; le traitement pourra reprendre'
        end

        publish(directory)
      end
    end

    private

    def publish(directory)
      guard = VideoAssets::ReconciliationVolumeGuard.new(root: '/videos')
      guard.call
      inventory = VideoLibraryInventory::Scanner.new(roots: ['/videos'], include_all_files: true).call
      if inventory[:entries].any? { |entry| %w[missing_root inaccessible].include?(entry[:type]) }
        raise ArgumentError, 'Scan incomplet, bilan précédent conservé'
      end

      source = VideoAssets::ReconciliationReport.new(inventory: inventory).call
      guard.call
      VideoAssets::ReconciliationJournal.new(directory: directory, automatic: true).call(report: source)
    end
  end
end
