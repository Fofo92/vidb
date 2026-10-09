# frozen_string_literal: true

module CatalogEnrichment
  # Selects only actionable identities; unresolved identities remain in the review report.
  class TmdbSelectedHierarchy
    def initialize(mapping:, snapshot:, catalogue:)
      @mapping = mapping.deep_stringify_keys
      @snapshot = snapshot
      @catalogue = catalogue
    end

    def call
      full = plan(@mapping)
      seasons = full.fetch(:seasons).reject { |season| season[:action] == 'needs_review' }.pluck(:local_season)
      selected = full.fetch(:episodes).select do |episode|
        %w[create_proposal reuse_proposal].include?(episode[:action]) &&
          seasons.include?(episode[:local_mapping]['local_season'])
      end
      prepare(full, selected)
    end

    private

    def plan(mapping)
      TmdbHierarchyPlan.new(mapping: mapping, snapshot: @snapshot, catalogue: @catalogue).call
    end

    def prepare(full, selected)
      raise ArgumentError, 'No unblocked identities to prepare' if selected.empty?

      mapping = @mapping.merge('episodes' => selected.pluck(:local_mapping))
      excluded = full.fetch(:episodes) - selected
      { read_only: true, mapping: mapping, hierarchy_plan: plan(mapping),
        selected_count: selected.size, excluded_count: excluded.size, excluded: excluded }
    end
  end
end
