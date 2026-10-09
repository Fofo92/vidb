# frozen_string_literal: true

module VideoAssets
  # Tracks observations without accepting candidates or changing availability.
  class ReconciliationFollowup
    FORMAT = 'vidb.reconciliation_followup'
    CANDIDATES = %w[exact convention episode_candidate].freeze

    def initialize(report:, previous: nil, assets: VideoAsset.where(status: 'present'))
      @report = report.deep_symbolize_keys
      @previous = previous&.deep_symbolize_keys
      @assets = assets.index_by(&:last_known_path)
    end

    def call
      validate!
      entries = @report.fetch(:observations).map { |item| follow(item) }
      result(entries)
    end

    private

    def validate!
      raise ArgumentError, 'Unsupported reconciliation report' unless valid_report?

      return unless @previous

      raise ArgumentError, 'Unsupported followup' unless @previous[:format] == FORMAT && @previous[:version] == 1
      raise ArgumentError, 'Inventory scope changed' unless roots == @previous.dig(:source_inventory, :roots)
      raise ArgumentError, 'Older inventory refused' if snapshot < Time.iso8601(@previous[:inventory_at])
    end

    def valid_report?
      @report[:format] == ReconciliationReport::FORMAT && @report[:version] == ReconciliationReport::VERSION
    end

    def roots
      @report.fetch(:source_inventory).fetch(:roots)
    end

    def snapshot
      Time.iso8601(@report.fetch(:source_inventory).fetch(:generated_at))
    end

    def follow(item)
      old = previous_entries[item.fetch(:path)]
      state = classification(item)
      item.merge(followup_status: state, first_seen_at: old&.fetch(:first_seen_at) || snapshot.iso8601,
                 changed_since_previous: changed?(old, item, state))
    end

    def changed?(old, item, state)
      old.present? && signature(old) != signature(item.merge(followup_status: state))
    end

    def classification(item)
      asset = @assets[item.fetch(:path)]
      return confirmed_state(asset, item) if asset
      return 'awaiting_stability' if Time.iso8601(item.fetch(:modified_at)) > (snapshot - 24.hours)
      return 'candidate' if CANDIDATES.include?(item[:status]) && item.fetch(:candidates, []).one?

      'needs_review'
    end

    def confirmed_state(asset, item)
      return 'confirmed_copy_changed' unless asset.byte_size == item.fetch(:size)

      modified_at = Time.iso8601(item.fetch(:modified_at))
      return 'confirmed_copy_changed' unless asset.observed_at && asset.observed_at >= modified_at

      'confirmed'
    end

    def previous_entries
      @previous_entries ||= (@previous&.fetch(:entries) || []).index_by { |item| item.fetch(:path) }
    end

    def signature(item)
      item.slice(:size, :modified_at, :status, :reason, :candidates, :followup_status)
    end

    def result(entries)
      paths = entries.pluck(:path)
      missing = previous_entries.keys - paths
      build_result(entries, missing)
    end

    def build_result(entries, missing)
      { format: FORMAT, version: 1, generated_at: Time.current.iso8601, inventory_at: snapshot.iso8601,
        source_inventory: @report.fetch(:source_inventory),
        counts: entries.group_by { |item| item[:followup_status] }.transform_values(&:count),
        new_paths: entries.pluck(:path) - previous_entries.keys, absent_since_previous: missing,
        entries: entries }
    end
  end
end
