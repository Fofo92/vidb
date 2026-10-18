module ReconciliationWorkbench
  class SeriesStructureAction
    def call(payload)
      root = Record.find(payload.fetch('record_id'))
      verify_root!(root, payload)
      qualify(root, 'series')
      index = SeriesTitles.index
      receipts = payload.fetch('operations').map { |operation| apply(root, operation, index) }
      { 'episodes' => receipts, 'held_files' => payload.fetch('held').size }
    end

    private

    def verify_root!(root, payload)
      return if root.root? && %w[series undetermined].include?(root.record_kind) &&
                root.language_version_id == payload.fetch('language_version_id')

      raise ArgumentError, 'Série ou langue héritée modifiée'
    end

    def apply(root, operation, index)
      existing = operation['existing_id']
      candidates = SeriesTitles.candidates(index, operation.fetch('observed_title'))
      raise ArgumentError, 'Une fiche concurrente est apparue depuis la proposition' unless
        candidates == (existing ? [existing] : [])

      season = season(root, operation)
      episode = episode(season, operation)
      qualify(episode, 'episode')
      index_episode(index, episode)
      { 'operation' => operation['kind'], 'season_id' => season.id, 'episode_id' => episode.id,
        'path' => operation['path'], 'references' => operation['references'] }
    end

    def index_episode(index, episode)
      [episode.french_title, episode.original_title].each do |title|
        key = SeriesTitles.key(title)
        index[key] = (index[key] + [episode.id]).uniq unless key.empty?
      end
    end

    def season(root, operation)
      number = operation.fetch('season')
      candidates = root.children.where(rank: number).to_a
      record = selected_season(root, operation, candidates)
      verify_season!(operation, record, candidates)
      record ||= create_season(root, number)
      correct_rank(record, operation)
      qualify(record, 'season')
      record
    end

    def selected_season(root, operation, candidates)
      expected = operation['season_id']
      return candidates.one? ? candidates.first : nil unless expected
      raise ArgumentError, 'Rang de saison concurrent' if candidates.any? { |record| record.id != expected }

      root.children.find(expected)
    end

    def correct_rank(record, operation)
      number = operation.fetch('season')
      return if record.rank == number
      raise ArgumentError, 'Rang de saison modifié' unless record.rank == operation.fetch('season_rank_before')

      update_structure(record, rank: number)
    end

    def verify_season!(operation, record, candidates)
      expected = operation['season_id']
      raise ArgumentError, 'Placement de saison modifié' if expected && record&.id != expected
      return if expected || candidates.empty? || @created_seasons&.include?(record&.id)

      raise ArgumentError, 'Saison concurrente apparue'
    end

    def create_season(root, number)
      record = root.children.create!(french_title: format('Saison %02d', number), rank: number,
                                     record_kind: 'season', language_version_id: root.language_version_id)
      (@created_seasons ||= []) << record.id
      record
    end

    def episode(season, operation)
      candidates = season.children.where(rank: operation.fetch('episode')).to_a
      if operation.fetch('kind') == 'reuse_episode'
        record = candidates.one? && candidates.first
        return record if reusable?(record, operation)
      elsif operation['kind'] == 'create_episode' && candidates.empty?
        return create_episode(season, operation)
      end
      raise ArgumentError, 'Épisode ou rang concurrent apparu'
    end

    def reusable?(record, operation)
      record && record.id == operation.fetch('existing_id') && !record.has_children?
    end

    def create_episode(season, operation)
      season.children.create!(operation.slice('french_title', 'original_title').merge(
                                'rank' => operation['episode'], 'record_kind' => 'episode',
                                'language_version_id' => season.root.language_version_id
                              ))
    end

    def qualify(record, kind)
      raise ArgumentError, 'Nature de fiche modifiée' unless ['undetermined', kind].include?(record.record_kind)
      return if record.record_kind == kind

      update_structure(record, record_kind: kind)
    end

    def update_structure(record, attributes)
      before = record.attributes
      record.update!(attributes)
      changed = before.keys.reject { |key| before[key] == record.attributes[key] }
      allowed = attributes.keys.map(&:to_s) + ['updated_at']
      raise ArgumentError, 'Une autre métadonnée serait modifiée' unless (changed - allowed).empty?
    end
  end
end
