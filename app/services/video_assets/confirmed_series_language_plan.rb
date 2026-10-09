# frozen_string_literal: true

require 'digest'
require 'json'

module VideoAssets
  class ConfirmedSeriesLanguagePlan
    def initialize(import_evidence:, observer: CatalogEnrichment::TechnicalObservation.new)
      @evidence = import_evidence.deep_stringify_keys
      @observer = observer
    end

    def call
      validate_scope!
      copies = @evidence.fetch('pairs').flat_map { |pair| pair.fetch('parts').map { |part| prepare(pair, part) } }
      report(copies)
    end

    private

    def validate_scope!
      valid = @evidence['format'] == 'vidb.broadcast_part_import' && @evidence['version'] == 1 &&
              @evidence['root_record_id'] == 3442 && @evidence.fetch('pairs').size == 18
      raise ArgumentError, 'This confirmation is restricted to the Blanca pilot' unless valid
    end

    def prepare(pair, part)
      asset = asset_for(pair, part)
      observed = @observer.call(part.fetch('path'))
      fresh = observed_asset(asset, observed)
      proposal = LanguageProposal.new(fresh).call
      proposal = ConfirmedSeriesLanguageDecision.call(proposal, fresh)
      copy = copy_evidence(asset, proposal)
      LanguageBatchChecks.new(@evidence).copy!(asset, copy, observed)
      copy
    end

    def asset_for(pair, part)
      asset = VideoAsset.find_by!(status: 'present', last_known_path: part.fetch('path'))
      valid = asset.record_id == pair.fetch('record_id') && asset.broadcast_part_number == part.fetch('part') &&
              asset.record.broadcast_part_count == 2 && asset.byte_size == part.fetch('size')
      raise ArgumentError, 'Apply the matching Blanca part import first' unless valid
      raise ArgumentError, 'Copy outside Blanca hierarchy' unless asset.record.ancestor_ids.include?(3442)

      asset
    end

    def observed_asset(asset, observed)
      fresh = asset.dup
      fresh.id = asset.id
      fresh.technical_details = asset.technical_details.merge(observed.fetch(:technical_details))
      fresh
    end

    def copy_evidence(asset, proposal)
      raise ArgumentError, 'Missing observation date' unless asset.observed_at

      proposal.stringify_keys.merge(
        'byte_size' => asset.byte_size, 'observed_at' => asset.observed_at.iso8601,
        'language_version' => proposal[:suggested_version],
        'basis' => proposal[:basis] || 'language_proposal_v2'
      )
    end

    def report(copies)
      { format: 'vidb.confirmed_series_language_plan', version: 1, applied: false,
        counts: copies.group_by { |copy| copy.fetch('status') }.transform_values(&:size),
        copies: copies, manifest: manifest(copies.select { |copy| copy['status'] == 'candidate' }) }
    end

    def manifest(copies)
      { format: 'vidb.video_asset_language_batch', version: 1, decided_by: 'Pascal', decided_on: '2026-10-09',
        storage_uuid: @evidence.fetch('storage_uuid'),
        source_report: { basis: 'Blanca VF confirmation except companion encoder projects',
                         import_manifest_sha256: Digest::SHA256.hexdigest(JSON.generate(@evidence)) }, copies: copies }
    end
  end
end
