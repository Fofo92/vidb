# frozen_string_literal: true

module VideoAssets
  class ConditionMarkerImport
    def call(apply: false)
      rows = []
      VideoAsset.find_each do |asset|
        proposal = LegacyConditionMarkers.call(asset.last_known_path)
        next if proposal.empty?

        status = classification(asset, proposal)
        status = import(asset, proposal) if apply && status == 'proposed'
        rows << report_row(asset, proposal, status)
      end
      { format: 'vidb.legacy_copy_conditions', version: 1, applied: apply,
        counts: rows.group_by { |row| row[:status] }.transform_values(&:size), copies: rows }
    end

    private

    def report_row(asset, proposal, status)
      { video_asset_id: asset.id, record_id: asset.record_id, path: asset.last_known_path,
        status: status, proposal: proposal }
    end

    def classification(asset, proposal)
      return asset.condition_details['needs_review'] ? 'needs_review' : 'preserved' if asset.condition_details.present?
      return 'needs_review' if proposal['needs_review']

      'proposed'
    end

    def import(asset, proposal)
      # Same lock order as copy state updates; no filesystem operation.
      asset.record.with_lock do
        asset.with_lock do
          fresh = LegacyConditionMarkers.call(asset.last_known_path)
          raise ArgumentError, 'Le nom de la copie a changé pendant l’import.' unless fresh == proposal
          return 'preserved' if asset.condition_details.present?

          write(asset, proposal)
        end
      end
    end

    def write(asset, proposal)
      evidence = proposal.deep_dup
      evidence['evidence'].first['imported_at'] = Time.current.iso8601(9)
      asset.update!(condition_details: evidence)
      'imported'
    end
  end
end
