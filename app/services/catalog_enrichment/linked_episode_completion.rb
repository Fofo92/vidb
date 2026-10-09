# frozen_string_literal: true

module CatalogEnrichment
  # Applies series metadata and measured copies in one transaction after fresh observation.
  class LinkedEpisodeCompletion
    def initialize(evidence:, snapshot:, observer: VideoAssets::BatchFileObservation.new)
      @evidence = evidence.deep_stringify_keys
      @snapshot = snapshot.deep_stringify_keys
      @candidates = LinkedCopyCandidates.new(@evidence)
      @observer = observer
    end

    def call(apply: false)
      observations = @candidates.entries.map { |entry| @observer.call(entry) }
      Record.transaction do
        lock_catalogue!
        complete(observations, apply)
      end
    end

    private

    def lock_catalogue!
      tables = 'records, video_assets, catalogue_episode_links'
      Record.connection.execute("LOCK TABLE #{tables} IN SHARE ROW EXCLUSIVE MODE")
    end

    def complete(observations, apply)
      metadata = TmdbOriginMetadata.new(evidence: @evidence, snapshot: @snapshot, records: @candidates.records)
      metadata_plan = metadata.plan
      plans = copy_plans(observations)
      observations.each { |observed| @observer.verify!(observed) }
      metadata.apply! if apply
      plans.each { |asset, attributes| asset.update!(attributes) } if apply
      report(plans, metadata_plan, metadata.labels, apply)
    end

    def copy_plans(observations)
      medium = Medium.find_by!(short_name: @evidence.fetch('medium'))
      builder = LinkedCopyAttributes.new(evidence: @evidence, medium: medium)
      @candidates.entries.zip(observations).map do |entry, observed|
        builder.plan(@candidates.owner(entry), entry, observed)
      end
    end

    def report(plans, metadata, labels, apply)
      { applied: apply, total: plans.length, metadata_total: metadata.length, metadata_labels: labels,
        metadata: metadata, copies: plans.map do |asset, attributes|
          attributes.merge(record_id: asset.record_id, video_asset_id: asset.id, path: asset.last_known_path)
        end }
    end
  end
end
