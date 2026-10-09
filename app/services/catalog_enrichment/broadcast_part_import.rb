# frozen_string_literal: true

module CatalogEnrichment
  # Atomic import; a pair's complementary files are never whole-copy alternatives.
  class BroadcastPartImport
    def initialize(evidence:, observer: VideoAssets::BatchFileObservation.new)
      @evidence = evidence.deep_symbolize_keys
      @observer = observer
    end

    def call(apply: false)
      entries = BroadcastPartImportPlan.new(evidence: @evidence).call
      raise ArgumentError, 'Duplicate file paths' unless entries.pluck(:path).uniq.size == entries.size

      observations = entries.map { |entry| @observer.call(entry) }
      import(entries, observations, apply)
    end

    private

    def import(entries, observations, apply)
      Record.transaction do
        lock_tables!
        raise ArgumentError, 'Catalogue changed during observation' unless entries == current_plan

        perform(entries, observations, apply)
      end
    end

    def lock_tables!
      Record.connection.execute('LOCK TABLE records, video_assets IN SHARE ROW EXCLUSIVE MODE')
    end

    def current_plan
      BroadcastPartImportPlan.new(evidence: @evidence).call
    end

    def perform(entries, observations, apply)
      plans = build_plans(entries, observations)
      observations.each { |observed| @observer.verify!(observed) }
      apply_plans(plans) if apply
      { applied: apply, episodes: entries.pluck(:record_id).uniq.size, files: plans.size,
        copies: copy_report(plans) }
    end

    def build_plans(entries, observations)
      builder = BroadcastPartCopy.new(evidence: @evidence)
      entries.zip(observations).map do |entry, observed|
        record = prepare_record(entry)
        builder.plan(record, entry, observed)
      end
    end

    def apply_plans(plans)
      root = Record.find(@evidence.fetch(:root_record_id))
      root.update!(record_kind: 'series') unless root.record_kind_series?
      plans.each do |asset, attributes|
        record = asset.record
        record.parent.update!(record_kind: 'season') unless record.parent.record_kind_season?
        record.save! if record.changed?
        asset.update!(attributes)
      end
    end

    def prepare_record(entry)
      record = Record.find(entry.fetch(:record_id))
      raise ArgumentError, 'Existing episode has another part count' unless [1, 2].include?(record.broadcast_part_count)

      record.assign_attributes(entry.fetch(:corrections).merge(broadcast_part_count: 2, record_kind: 'episode'))
      record
    end

    def copy_report(plans)
      plans.map do |asset, _attributes|
        asset.slice(:id, :record_id, :last_known_path, :broadcast_part_number)
      end
    end
  end
end
