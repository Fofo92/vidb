module VideoAssets
  class ConsolidationCases
    PRIORITIES = %w[ambiguous_identification ambiguous_hierarchy numbering_conflict title_conflict copy_changed
                    parent_placement container_kind_review title_variant language_review
                    missing_episode missing_season missing_hierarchy series_identification
                    work_identification candidate other_review].freeze
    LABELS = {
      "ambiguous_identification" => "Identité ambiguë", "ambiguous_hierarchy" => "Hiérarchie ambiguë",
      "numbering_conflict" => "Numérotation à vérifier", "title_conflict" => "Titre en conflit",
      "copy_changed" => "Copie modifiée", "parent_placement" => "Placement à vérifier",
      "container_kind_review" => "Nature à vérifier", "title_variant" => "Variante de titre",
      "language_review" => "Langue à vérifier", "missing_episode" => "Épisode non retrouvé",
      "missing_season" => "Saison non retrouvée", "missing_hierarchy" => "Hiérarchie à compléter",
      "series_identification" => "Série à identifier", "work_identification" => "Œuvre à identifier",
      "candidate" => "Candidat à importer", "other_review" => "Autre contrôle"
    }.freeze

    def initialize(followup:, language_exceptions: [])
      @followup = followup
      @language_exceptions = language_exceptions.map(&:deep_symbolize_keys)
    end

    def call
      summary = BlockageSummary.new(followup: @followup).call
      groups = summary.fetch(:groups).reject do |group|
        %w[confirmed awaiting_stability excluded_trash excluded_workspace].include?(group[:category])
      end
      groups += language_groups
      cases = ordered_cases(groups)
      cases.each_with_index { |item, index| item[:case_number] = index + 1 }
      { format: "vidb.consolidation_cases", version: 1, inventory_at: summary.fetch(:inventory_at),
        file_counts: summary.fetch(:counts), case_count: cases.length, cases: cases }
    end

    private

    def ordered_cases(groups)
      cases = groups.group_by { |group| group.fetch(:directory) }.map do |directory, items|
        build_case(directory, items)
      end
      cases.sort_by { |item| [priority(item), -item[:file_count], item[:directory]] }
    end

    def language_groups
      @language_exceptions.group_by { |item| directory(item.fetch(:path)) }.map do |path, items|
        { directory: path, category: "language_review", file_count: items.length,
          suggested_action: "Vérifier la marque du titre et les pistes audio ; qualification linguistique uniquement.",
          reasons: items.group_by { |item| item[:reason] }.transform_values(&:length),
          record_ids: [], paths: items.pluck(:path), examples: items.first(3) }
      end
    end

    def directory(path)
      parent = File.dirname(path)
      /\ASaison\s+\d+\b/i.match?(File.basename(parent)) ? File.dirname(parent) : parent
    end

    def build_case(directory, groups)
      paths = groups.flat_map { |group| group.fetch(:paths) }.uniq.sort
      { directory: directory, file_count: paths.length,
        categories: groups.to_h { |group| [group.fetch(:category), group.fetch(:file_count)] },
        actions: groups.map { |group| group.fetch(:suggested_action) }.uniq,
        reasons: groups.to_h { |group| [group.fetch(:category), group.fetch(:reasons)] },
        record_ids: groups.flat_map { |group| group.fetch(:record_ids) }.uniq.sort,
        examples: groups.flat_map { |group| group.fetch(:examples) }.first(5), paths: paths }
    end

    def priority(item)
      item.fetch(:categories).keys.map { |category| PRIORITIES.index(category) || PRIORITIES.length }.min
    end
  end
end
