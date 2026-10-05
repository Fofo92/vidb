# frozen_string_literal: true

module VideoAssets
  # Builds a read-only report from a historical filesystem inventory.
  class ReconciliationReport
    ELIGIBLE_EXTENSIONS = %w[.avi .m4v .mkv].freeze
    FORMAT = 'vidb.video_asset_reconciliation'
    VERSION = 4
    SOURCE_FORMAT = 'vidb.video_library_inventory'
    SOURCE_VERSION = 1
    EPISODE_PREFIX = /\A\s*(?:S\d+\s*E\d+\b|E\d+\b|[ÉE]pisode\s+\d+\b)/i

    def initialize(inventory:, records: Record.all)
      @inventory = inventory.deep_symbolize_keys
      records = records.to_a
      @matcher = TitleMatcher.new(records)
      @episode_matcher = EpisodeMatcher.new(records)
    end

    def call
      validate_inventory!
      observations = eligible_entries.map { |entry| reconcile(entry) }
      build_report(observations)
    end

    private

    attr_reader :inventory, :matcher

    def build_report(observations)
      {
        format: FORMAT,
        version: VERSION,
        generated_at: Time.current.iso8601,
        source_inventory: source_inventory,
        summary: observations.group_by { |item| item[:status] }.transform_values(&:count),
        multiple_file_candidates: multiple_file_candidates(observations),
        observations: observations
      }
    end

    def validate_inventory!
      return if inventory[:format] == SOURCE_FORMAT &&
                inventory[:version] == SOURCE_VERSION

      raise ArgumentError, 'unsupported video library inventory'
    end

    def eligible_entries
      inventory.fetch(:entries).select do |entry|
        entry[:type] == 'file' && ELIGIBLE_EXTENSIONS.include?(entry[:extension])
      end
    end

    def reconcile(entry)
      match = episode_entry?(entry) ? @episode_matcher.match(entry) : matcher.match(entry[:stem])
      observation(entry).merge(match)
    end

    def episode_entry?(entry)
      entry[:episode].present? || EPISODE_PREFIX.match?(entry[:stem].to_s)
    end

    def multiple_file_candidates(observations)
      unique_matches = observations.select do |item|
        %w[exact convention episode_candidate].include?(item[:status]) && item[:candidates].one?
      end
      unique_matches.group_by { |item| item[:candidates].first[:record_id] }
                    .filter_map do |record_id, items|
        paths = items.pluck(:path).uniq
        next unless paths.many?

        { record_id: record_id, paths: paths }
      end
    end

    def observation(entry)
      entry.slice(:path, :relative_path, :extension, :stem, :size, :modified_at)
    end

    def source_inventory
      inventory.slice(:format, :version, :generated_at, :roots)
    end
  end
end
