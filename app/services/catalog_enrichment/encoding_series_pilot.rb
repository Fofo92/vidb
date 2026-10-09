# frozen_string_literal: true

module CatalogEnrichment
  class EncodingSeriesPilot
    def initialize(config:, snapshot:, inventory:, catalogue:, now: Time.current)
      @config = config.deep_stringify_keys
      @snapshot = snapshot.deep_stringify_keys
      @inventory = inventory.deep_stringify_keys
      @catalogue = catalogue.map(&:deep_stringify_keys)
      @now = now
    end

    def call
      validate!
      comparison = compare
      proposals = EncodingPilotMapping.new(comparison: comparison, inventory: @inventory, catalogue: @catalogue,
                                           root_record_id: @config.fetch('root_record_id'), now: @now).call
      mapping = mapping_payload(proposals.fetch(:episodes))
      plan = hierarchy_plan(mapping)
      payload(proposals, mapping, plan, comparison)
    end

    private

    def payload(proposals, mapping, plan, comparison)
      { format: 'vidb.encoding_series_pilot', version: 1, read_only: true,
        generated_at: @now.iso8601, root_record_id: @config.fetch('root_record_id'),
        tmdb_series_id: @config.fetch('tmdb_series_id'), counts: proposals.fetch(:counts),
        project_only_count: project_only_count, observations: proposals.fetch(:entries),
        comparison: comparison, mapping: mapping, hierarchy_plan: plan }
    end

    def validate!
      unless @config['format'] == 'vidb.encoding_series_pilot_config' && @config['version'] == 1
        raise ArgumentError, 'Unsupported pilot configuration'
      end

      validate_identity!
      validate_inventory!
    end

    def validate_identity!
      root = @catalogue.find { |record| record['id'] == @config.fetch('root_record_id') }
      valid = root && root['ancestry'].blank? && root['french_title'] == @config.fetch('series_title') &&
              root['record_kind'] == 'series' && @snapshot['tmdb_series_id'] == @config.fetch('tmdb_series_id') &&
              @snapshot.dig('series', 'original_name') == @config.fetch('original_series_title')
      raise ArgumentError, 'Selected series identity changed; pilot stopped' unless valid
    end

    def validate_inventory!
      raise ArgumentError, 'Unexpected pilot inventory scope' unless @inventory['roots'] == [@config.fetch('directory')]

      errors = @inventory.fetch('entries').any? { |entry| %w[missing_root inaccessible].include?(entry['type']) }
      raise ArgumentError, 'Incomplete pilot scan; no plan published' if errors
    end

    def compare
      report = VideoAssets::ReconciliationReport.new(inventory: @inventory, records: []).call.deep_stringify_keys
      TmdbEpisodeComparison.new(snapshot: @snapshot, reconciliation: report,
                                directory: @config.fetch('directory'), catalogue: @catalogue).call
    end

    def mapping_payload(episodes)
      { format: 'vidb.local_tmdb_episode_mapping', version: 1, read_only: true,
        root_record_id: @config.fetch('root_record_id'), series_title: @config.fetch('series_title'),
        original_series_title: @config.fetch('original_series_title'), tmdb_series_id: @config.fetch('tmdb_series_id'),
        source_snapshot_retrieved_at: @snapshot.fetch('retrieved_at'), local_order_is_authoritative: true,
        episodes: local_titles(episodes) }
    end

    def local_titles(episodes)
      titles = EncodingPilotTitles.new(overrides: @config.fetch('local_title_overrides', {}))
      episodes.map { |entry| titles.call(entry).deep_symbolize_keys }
    end

    def hierarchy_plan(mapping)
      return nil if mapping.fetch(:episodes).empty?

      TmdbHierarchyPlan.new(mapping: mapping, snapshot: @snapshot, catalogue: @catalogue).call
    end

    def project_only_count
      @inventory.fetch('pairs', []).count do |pair|
        pair['status'] == 'json_only' && !pair['directory'].include?('video_encoder_')
      end
    end
  end
end
