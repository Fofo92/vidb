# frozen_string_literal: true

module VideoAssets
  # Called within CompletedExportImport's transaction, after record/file validation.
  class CompletedExportRelocation
    PATH_FIELDS = %w[previous_output_path project_path output_path project_sha256].freeze

    def initialize(record, observation, export)
      @record = record
      @path = observation.fetch(:path)
      @export = export
      @receipt = export.fetch(:receipt)
    end

    def call
      previous = @receipt['previous_output_path']
      return unless previous

      validate_path!(previous)
      asset = previous_asset(previous)
      return unless asset
      return if old_file_exists?(asset.last_known_path)

      relocate(asset)
    end

    private

    def validate_path!(path)
      valid = path.is_a?(String) && !path.include?("\0") && Pathname.new(path).absolute? &&
              Pathname.new(path).cleanpath.to_s == path && path != @path
      raise ArgumentError, 'Ancien chemin du reçu invalide' unless valid
    end

    def previous_asset(path)
      candidates = relocation_candidates(path)
      return if candidates.empty?
      return candidates.sole if candidates.one? && same_export?(candidates.sole)

      raise ArgumentError, 'Ancienne copie ambiguë ou différente du reçu : déplacement à examiner'
    end

    def relocation_candidates(path)
      direct = VideoAsset.where(last_known_path: path).lock.to_a
      return direct unless direct.empty?

      VideoAsset.where(record_id: @record.id, status: %w[present missing]).lock.select do |asset|
        same_export?(asset)
      end
    end

    def same_export?(asset)
      recorded = asset.technical_details['video_encoder_export']
      return false unless asset.record_id == @record.id && %w[present missing].include?(asset.status) &&
                          recorded.is_a?(Hash) && asset.byte_size == @receipt['byte_size']

      same_project = recorded['project_sha256'] == @receipt['project_sha256'] ||
                     (@receipt['project_id'].present? && recorded['project_id'] == @receipt['project_id'])
      same_project && stable_receipt(recorded) == stable_receipt(@receipt)
    end

    def stable_receipt(receipt)
      stable = receipt.except(*PATH_FIELDS).deep_dup
      stable.dig('probe', 'format')&.delete('filename')
      stable
    end

    def old_file_exists?(path)
      File.lstat(path)
      true
    rescue Errno::ENOENT, Errno::ENOTDIR
      false
    end

    def relocate(asset)
      previous = asset.last_known_path
      history = asset.technical_details.fetch('relocation_history', [])
      event = { 'from' => previous, 'to' => @path, 'previous_status' => asset.status,
                'moved_at' => Time.current.iso8601(9), 'origin' => 'video_encoder_receipt',
                'previous_receipt' => asset.technical_details['video_encoder_export'] }
      details = asset.technical_details.merge(@export.fetch(:details)).merge(
        'video_encoder_export' => @receipt, 'relocation_history' => history + [event]
      )
      asset.update!(last_known_path: @path, status: 'present', observed_at: Time.current, technical_details: details)
      { status: 'relocated', record_id: @record.id, video_asset_id: asset.id, previous_path: previous }
    end
  end
end
