module ReconciliationWorkbench
  class DiskAction
    def initialize(observer: VideoAssets::BatchFileObservation.new,
                   guard: VideoAssets::ReconciliationVolumeGuard.new(root: '/videos'))
      @observer = observer
      @guard = guard
    end

    def observe(payload)
      @guard.call
      path = payload.fetch('path')
      actual = VideoAssets::RelocationFileIdentity.call(File.lstat(path)).as_json
      raise ArgumentError, 'Identité physique modifiée' unless actual == payload.fetch('identity')
      raise ArgumentError, 'Chemin symbolique refusé' unless File.realpath(path) == path

      @observer.call(payload.fetch('entry').deep_symbolize_keys)
    end

    def call(payload, observed)
      record = Record.find(payload.fetch('record_id'))
      raise ArgumentError, 'Type ou placement non qualifié' unless record.hierarchy_placement_status == :consistent

      guard_conflicts!(record, payload.fetch('path'))
      # Make the availability transition part of the same SQL transaction as the case receipt.
      record.update!(is_available: true, is_recorded: true)
      result = import(payload, observed)
      asset = VideoAsset.find_by!(status: 'present', record_id: record.id, last_known_path: payload.fetch('path'))
      asset.update!(language_version_id: record.language_version_id) if asset.language_version_id.nil?
      @observer.verify!(observed)
      @guard.call
      result.slice(:applied, :total).merge(video_asset_id: asset.id)
    end

    private

    def import(payload, observed)
      evidence = { format: 'vidb.video_asset_import_batch', version: 1, medium: 'HD',
                   storage_uuid: '3430606f-92bb-4da4-aaf2-36a3460bc298',
                   source_inventory: payload.fetch('source_inventory'),
                   selection_policy: 'approved_unique_stable_copy_v1', entries: [payload.fetch('entry')] }
      cached = CachedObserver.new(observed, @observer)
      VideoAssets::BatchImport.new(evidence: evidence, observer: cached).call(apply: true)
    end

    def guard_conflicts!(record, path)
      existing = VideoAsset.where(status: 'present').where('record_id = ? OR last_known_path = ?', record.id, path)
      raise ArgumentError, 'Une copie est apparue depuis la proposition' if existing.exists?
    end

    class CachedObserver
      def initialize(observed, delegate)
        @observed = observed
        @delegate = delegate
      end

      def call(_entry)
        @observed
      end

      def verify!(observed)
        @delegate.verify!(observed)
      end
    end
  end
end
