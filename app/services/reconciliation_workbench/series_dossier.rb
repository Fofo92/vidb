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
      if group['proposed_new_root']
        receipt = creation_receipt(group)
        return [receipt] if receipt
      end
      root = proposed_root(group)
      payload = compile(group, root, index)
      payload.merge!('inventory_at' => document.fetch('inventory_at'), 'inputs' => document.fetch('inputs'),
                     'reference_attribution' => document.fetch('reference_attribution'))
      item = publish(group, payload)
      payload['new_root'] ? [item] : [item, *SeriesYearProposals.new.call(item.payload)]
    end

    def proposed_root(group)
      return SeriesEvidence.identity!(group['proposed_existing_root']) if group['proposed_existing_root']

      SeriesCreation.preview(group) if group['proposed_new_root']
    end

    def publish(group, payload)
      rule = payload['new_root'] ? Rules::SERIES_CREATION : Rules::SOURCED_STRUCTURE
      item = CaseStore.propose(rule: rule, key: "series:#{group.fetch('directory')}",
                               payload: payload, preserve_pending: true)
      item.update!(status: 'blocked', error: exclusion_summary(item.payload)) if
        item.status == 'pending' && item.payload.fetch('operations').empty?
      item
    end

    def creation_receipt(group)
      raise ArgumentError, 'Choisir création ou série existante' if group['proposed_existing_root']

      ReconciliationCase.find_by(rule_key: Rules::SERIES_CREATION.key,
                                 case_key: "series:#{group.fetch('directory')}", status: 'applied')
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
      selected = root&.new_record? && SeriesCreation.conflicts(root, index).any? ? nil : root
      plans = rows.map { |row| plan_row(group, selected, index, row) }
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
      return true if root.new_record?

      root.children.all? do |child|
        %w[season undetermined].include?(child.record_kind) && child.french_title.to_s.match?(/\ASaison\s+\d+\z/i)
      end
    end

    def payload(group, root, operations, held, sources)
      { 'record_id' => root&.id, 'title' => group.fetch('name'), 'file_count' => group.fetch('file_count'),
        'episode_source_policy' => EpisodeSourcePolicy::VERSION,
        'season_references' => group.fetch('season_references', []),
        'directory' => group.fetch('directory'), 'operations' => operations, 'held' => held,
        'language_version_id' => root&.language_version_id, 'language_label' => root&.language_version&.long_name,
        'reference_show' => group.fetch('reference_show', {}).slice('name', 'premiered', 'ended', 'language'),
        'sources' => sources, 'records' => snapshot_records(root),
        'reason' => 'Créer les saisons et épisodes manquants ou qualifier les fiches concordantes. ' \
                    'Titres existants conservés ; langue des nouvelles fiches héritée de la série.' }
        .merge(creation_attributes(root))
    end

    def creation_attributes(root)
      root&.new_record? ? { 'new_root' => root.attributes.slice('french_title', 'original_title') } : {}
    end

    def snapshot_records(root)
      records = root&.persisted? ? [root, *root.descendants.order(:id).to_a] : []
      records.to_h { |record| [record.id.to_s, Snapshot.record(record)] }
    end
  end
end
