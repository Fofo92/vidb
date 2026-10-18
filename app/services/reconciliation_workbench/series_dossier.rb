module ReconciliationWorkbench
  class SeriesDossier
    FORMAT = 'vidb.series_structure_preparation'.freeze

    def call(document)
      validate!(document)
      Record.transaction do
        index = SeriesTitles.index
        document.fetch('groups').flat_map { |group| propose(group, document, index) }
      end
    end

    private

    def validate!(document)
      groups = document.fetch('groups')
      raise ArgumentError, 'Version de dossier incompatible' unless document['version'] == 1
      raise ArgumentError, 'Nombre de groupes incohérent' unless groups.size == document.fetch('series_group_count')

      paths = groups.flat_map { |group| group.fetch('files').map { |row| row.fetch('path') } }
      return if paths.size == document.fetch('file_count') && paths.uniq.size == paths.size

      raise ArgumentError, 'Nombre de fichiers incohérent ou chemin répété'
    end

    def propose(group, document, index)
      root = SeriesEvidence.identity!(group['proposed_existing_root']) if group['proposed_existing_root']
      payload = compile(group, root, index)
      payload.merge!('inventory_at' => document.fetch('inventory_at'), 'inputs' => document.fetch('inputs'),
                     'reference_attribution' => document.fetch('reference_attribution'))
      item = CaseStore.propose(rule: Rules::SOURCED_STRUCTURE, key: "series:#{group.fetch('directory')}",
                               payload: payload, preserve_pending: true)
      item.update!(status: 'blocked', error: exclusion_summary(item.payload)) if
        item.status == 'pending' && item.payload.fetch('operations').empty?
      [item, *SeriesYearProposals.new.call(item.payload)]
    end

    def exclusion_summary(payload)
      reasons = payload.fetch('held').group_by { |row| row.fetch('reason') }
      details = reasons.map { |reason, rows| "#{rows.size} : #{reason}" }.join(' ; ')
      "Aucune opération applicable. #{details}"
    end

    def compile(group, root, index)
      rows = group.fetch('files')
      raise ArgumentError, 'Nombre de fichiers de la série incohérent' unless rows.size == group.fetch('file_count')

      sources = [SeriesEvidence.source!(group.fetch('reference_url'))]
      plans = rows.map { |row| plan_row(group, root, index, row) }
      operations, held = plans.partition { |plan| plan.key?('kind') }
      operations, conflicts = unique_operations(operations)
      held.concat(conflicts)
      payload(group, root, operations, held, sources)
    end

    def unique_operations(operations)
      counts = operations.group_by { |operation| operation.values_at('season', 'episode') }
      operations.partition { |operation| counts.fetch(operation.values_at('season', 'episode')).one? }
                .then do |unique, conflicts|
        [unique, conflicts.map do |operation|
          { 'path' => operation['path'], 'reason' => 'Plusieurs fichiers proposent le même rang d’épisode',
            'candidate_ids' => Array(operation['existing_id']) }
        end]
      end
    end

    def plan_row(group, root, index, row)
      if root&.root? && %w[series undetermined].include?(root.record_kind) && seasonal_branch?(root) &&
         group.fetch('other_same_title_roots').empty?
        row.fetch('existing_season_candidates').each { |candidate| SeriesEvidence.identity!(candidate) }
        return SeriesEpisodePlan.new(root, group, index).call(row)
      end

      { 'path' => row.fetch('path'), 'reason' => 'Identité de série ou branche existante à arbitrer',
        'candidate_ids' => SeriesTitles.candidates(index, row.fetch('observed_title')) }
    end

    def seasonal_branch?(root)
      root.children.all? do |child|
        %w[season undetermined].include?(child.record_kind) && child.french_title.to_s.match?(/\ASaison\s+\d+\z/i)
      end
    end

    def payload(group, root, operations, held, sources)
      records = root ? [root, *root.descendants.order(:id).to_a] : []
      { 'record_id' => root&.id, 'title' => group.fetch('name'), 'file_count' => group.fetch('file_count'),
        'episode_source_policy' => EpisodeSourcePolicy::VERSION,
        'season_references' => group.fetch('season_references', []),
        'directory' => group.fetch('directory'), 'operations' => operations, 'held' => held,
        'language_version_id' => root&.language_version_id, 'language_label' => root&.language_version&.long_name,
        'reference_show' => group.fetch('reference_show', {}).slice('name', 'premiered', 'ended', 'language'),
        'sources' => sources, 'records' => records.to_h { |record| [record.id.to_s, Snapshot.record(record)] },
        'reason' => 'Créer les saisons et épisodes manquants ou qualifier les fiches concordantes. ' \
                    'Titres existants conservés ; langue des nouvelles fiches héritée de la série.' }
    end
  end
end
