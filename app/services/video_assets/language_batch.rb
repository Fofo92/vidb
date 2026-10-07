# frozen_string_literal: true

require 'digest'
require 'json'

module VideoAssets
  class LanguageBatch
    def initialize(evidence:, observer: CatalogEnrichment::TechnicalObservation.new)
      @evidence = evidence
      @observer = observer
      @checks = LanguageBatchChecks.new(evidence)
      @checks.manifest!
    end

    def call(apply: false)
      observations = copies.to_h { |copy| [copy.fetch('video_asset_id'), @observer.call(copy.fetch('path'))] }
      VideoAsset.transaction do
        lock_owners
        plans = copies.sort_by { |copy| copy.fetch('video_asset_id') }.map do |copy|
          plan(copy, observations.fetch(copy.fetch('video_asset_id')))
        end
        copies.each { |copy| @checks.unchanged_file!(copy) }
        plans.each { |asset, attributes| asset.update!(attributes) unless attributes.empty? } if apply
        report(plans, apply)
      end
    end

    private

    def copies
      @evidence.fetch('copies')
    end

    def lock_owners
      records = Record.where(id: copies.map { |copy| copy.fetch('record_id') })
      ids = records.flat_map { |record| [record.id, *record.ancestor_ids] }.uniq
      Record.where(id: ids).order(:id).lock.load
    end

    def plan(copy, observed)
      asset = VideoAsset.lock.find(copy.fetch('video_asset_id'))
      @checks.copy!(asset, copy, observed)
      version = LanguageVersion.find_by!(short_name: copy.fetch('language_version'))
      return [asset, {}] if already_applied?(asset, version)
      raise ArgumentError, "Existing language qualification: #{asset.id}" if asset.language_version_id

      @checks.proposal!(asset, copy, observed)
      [asset, { language_version_id: version.id, technical_details: qualified_details(asset, copy, observed) }]
    end

    def already_applied?(asset, version)
      asset.language_version_id == version.id &&
        asset.technical_details.dig('language_qualification', 'batch_digest') == batch_digest
    end

    def qualified_details(asset, copy, observed)
      qualification = @evidence.slice('decided_by', 'decided_on', 'source_report').merge(
        copy.slice('basis', 'reason', 'language_version', 'filename_evidence', 'encoder_evidence')
      )
      qualification.merge!('batch_digest' => batch_digest, 'applied_at' => Time.current.iso8601,
                           'checked_streams' => observed.fetch(:technical_details).fetch('streams'))
      asset.technical_details.merge('language_qualification' => qualification)
    end

    def batch_digest
      @batch_digest ||= Digest::SHA256.hexdigest(JSON.generate(@evidence))
    end

    def report(plans, apply)
      { applied: apply, total: plans.size, changes: plans.count { |_, attributes| attributes.present? },
        copies: plans.map do |asset, attributes|
          { video_asset_id: asset.id, record_id: asset.record_id,
            language_version_id: attributes[:language_version_id] || asset.language_version_id,
            status: attributes.empty? ? 'already_applied' : 'planned' }
        end }
    end
  end
end
