module ReconciliationWorkbench
  # The ordinary unique-copy importer remains strict. This variant is limited
  # to the exact concurrent copies measured by the approved comparison.
  class CandidateImport < VideoAssets::BatchImport
    def initialize(payload:, sample:, assets:)
      @allowed_ids = assets.map(&:id)
      @receipt = sample['encoder_receipt']
      observed = sample.fetch('measurement').symbolize_keys.merge(observed_at: Time.current)
      delegate = VideoAssets::BatchFileObservation.new
      super(evidence: CandidateCopy.evidence(payload), observer: DiskAction::CachedObserver.new(observed, delegate))
    end

    private

    def existing_or_new(record, path)
      current = VideoAsset.where(status: 'present').where('record_id = ? OR last_known_path = ?', record.id, path)
      assets = current.order(:id).lock.to_a
      unless assets.map(&:id) == @allowed_ids && assets.none? { |asset| asset.last_known_path == path }
        raise ArgumentError, 'Les copies concurrentes ont changé'
      end

      VideoAsset.new(record: record, last_known_path: path, status: 'present')
    end

    def technical_details(asset, observed)
      details = super
      @receipt ? details.merge('video_encoder_export' => @receipt) : details
    end
  end
end
