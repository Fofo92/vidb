module ReconciliationWorkbench
  class CopyObservation
    def initialize(observer: VideoAssets::BatchFileObservation.new,
                   guard: VideoAssets::ReconciliationVolumeGuard.new(root: '/videos'),
                   encoder: ->(path) { VideoAssets::CompletedExport.new(path).call }, root: '/videos')
      @observer = observer
      @guard = guard
      @encoder = encoder
      @root = root
    end

    def inputs(assets)
      @guard.call
      assets.map do |asset|
        path = asset.last_known_path
        raise ArgumentError, 'Chemin de copie hors du volume ou symbolique' unless safe_path?(path)

        stat = File.lstat(path)
        validate_asset!(asset, stat)
        { 'asset_id' => asset.id, 'path' => path, 'modified_at' => stat.mtime.iso8601(9),
          'identity' => VideoAssets::RelocationFileIdentity.call(stat).as_json, 'snapshot' => Snapshot.asset(asset) }
      end
    end

    def measure(inputs)
      samples = inputs.map do |input|
        path = input.fetch('path')
        entry = { path: path, size: File.size(path), modified_at: File.mtime(path).iso8601 }
        measured = @observer.call(entry).as_json.except('observed_at')
        receipt = encoder_receipt(input)
        input.merge('measurement' => measured, 'encoder_verified' => receipt.present?, 'encoder_receipt' => receipt)
      end
      verify!(samples)
      samples
    end

    def verify!(samples)
      samples.each do |sample|
        actual = VideoAssets::RelocationFileIdentity.call(File.lstat(sample.fetch('path'))).as_json
        raise ArgumentError, 'Copie modifiée depuis la comparaison' unless actual == sample.fetch('identity')
      end
      @guard.call
    end

    private

    def safe_path?(path)
      path.present? && path.start_with?("#{@root}/") && Pathname.new(path).cleanpath.to_s == path &&
        File.realpath(path) == path
    end

    def validate_asset!(asset, stat)
      raise ArgumentError, 'Copie non stabilisée depuis 24 heures' unless stat.file? && stat.mtime < 24.hours.ago
      return if asset.byte_size == stat.size && asset.observed_at && asset.observed_at >= stat.mtime

      raise ArgumentError, 'Copie à réobserver avant comparaison'
    end

    def encoder_receipt(input)
      expected = input.dig('snapshot', 'technical_details', 'video_encoder_export')
      unless (expected.present? || input['candidate']) && File.file?("#{input.fetch('path')}#{VideoAssets::CompletedExport::SUFFIX}")
        return nil
      end

      actual = @encoder.call(input.fetch('path')).fetch(:receipt)
      actual if input['candidate'] || actual == expected
    end
  end
end
