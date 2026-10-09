# frozen_string_literal: true

module VideoAssets
  # Groups pending work by directory; counts files, not manual interventions.
  class BlockageSummary
    ACTIONS = {
      'confirmed' => 'Aucune action de rapprochement',
      'awaiting_stability' => 'Attendre la fin des écritures et au moins 24 heures avant le lot contrôlé',
      'candidate' => 'Lot contrôlé possible après vérification de stabilité et identité',
      'copy_changed' => 'Nouvelle observation technique avant toute actualisation',
      'series_identification' => 'Identifier la série et consulter une source extérieure',
      'work_identification' => 'Rechercher une fiche existante ou une identité extérieure',
      'missing_hierarchy' => 'Préparer une hiérarchie depuis une source extérieure',
      'missing_season' => 'Comparer les saisons avec une source extérieure',
      'missing_episode' => 'Comparer les épisodes avec une source extérieure',
      'parent_placement' => 'Vérifier le placement de la fiche existante',
      'container_kind_review' => 'Vérifier le type et la structure de la fiche',
      'numbering_conflict' => 'Vérifier la numérotation locale et extérieure',
      'title_variant' => 'Comparer les titres français et originaux',
      'title_conflict' => 'Vérifier l’identité de l’épisode avant correction',
      'ambiguous_identification' => 'Départager les fiches candidates',
      'ambiguous_hierarchy' => 'Départager les saisons candidates',
      'excluded_trash' => 'Hors périmètre : corbeille',
      'excluded_workspace' => 'Hors périmètre : fichier de travail d’encodage',
      'other_review' => 'Examiner les preuves du rapprochement'
    }.freeze

    def initialize(followup:)
      @followup = followup.deep_symbolize_keys
    end

    def call
      validate!
      entries = @followup.fetch(:entries)
      { format: 'vidb.reconciliation_blockages', version: 1, inventory_at: @followup.fetch(:inventory_at),
        total_files: entries.size, counts: counts(entries), groups: groups(entries),
        absent_since_previous: @followup.fetch(:absent_since_previous, []) }
    end

    private

    def validate!
      return if @followup[:format] == ReconciliationFollowup::FORMAT && @followup[:version] == 1

      raise ArgumentError, 'Unsupported reconciliation followup'
    end

    def counts(entries)
      entries.group_by { |entry| BlockageCategory.call(entry) }.transform_values(&:count)
    end

    def groups(entries)
      grouped = entries.group_by { |entry| [BlockageCategory.call(entry), directory(entry)] }
      grouped.map { |(category, path), items| group(category, path, items) }
             .sort_by { |item| [-item[:file_count], item[:directory], item[:category]] }
    end

    def directory(entry)
      parent = File.dirname(entry.fetch(:path))
      return File.dirname(parent) if /\ASaison\s+\d+\b/i.match?(File.basename(parent))

      parent
    end

    def group(category, path, entries)
      { category: category, directory: path, file_count: entries.size, suggested_action: ACTIONS.fetch(category),
        reasons: entries.group_by { |entry| entry[:reason] || entry[:title_evidence] || entry[:status] }
                        .transform_values(&:count),
        record_ids: record_ids(entries), examples: entries.first(3), paths: entries.pluck(:path) }
    end

    def record_ids(entries)
      candidates = entries.flat_map do |entry|
        entry.fetch(:candidates, []) + entry.fetch(:container_candidates, [])
      end
      candidates.filter_map { |candidate| candidate[:record_id] }.uniq.sort
    end
  end
end
