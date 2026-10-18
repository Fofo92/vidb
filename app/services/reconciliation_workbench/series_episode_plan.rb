module ReconciliationWorkbench
  class SeriesEpisodePlan
    def initialize(root, group, index)
      @root = root
      @group = group
      @index = index
    end

    def call(row)
      return held(row, 'Fichier multiple ou numérotation du fichier à arbitrer') unless single_file?(row)

      references = SeriesEvidence.references(row)
      return held(row, 'Titre et numéro non confirmés ensemble par une source') if references.empty?

      season = season_for(row)
      return held(row, 'Saison, rang ou placement à arbitrer') if season == false

      episode(row, season, references)
    end

    private

    def single_file?(row)
      row['multi_episode_numbers'].blank? && row['local_season'].is_a?(Integer) &&
        row['local_season'].positive? && row['local_episode'].is_a?(Integer) &&
        row['local_episode'].positive? && SeriesEvidence.file_matches?(row, @group.fetch('directory'))
    end

    def season_for(row)
      candidates = @root.children.select do |child|
        child.rank == row['local_season'] || season_number(child) == row['local_season']
      end
      return nil if candidates.empty?
      return false unless candidates.one?

      season = candidates.first
      valid_season?(season, row['local_season']) ? season : false
    end

    def season_number(record)
      match = record.french_title.to_s.match(/\ASaison\s+(\d+)\z/i)
      match && match[1].to_i
    end

    def valid_season?(season, number)
      %w[undetermined season].include?(season.record_kind) &&
        season_number(season) == number && season.children.all? do |child|
          %w[undetermined episode].include?(child.record_kind) && !child.has_children?
        end
    end

    def episode(row, season, references)
      candidates = SeriesTitles.candidates(@index, row.fetch('observed_title'))
      positioned = season ? season.children.where(rank: row['local_episode']).to_a : []
      reusable = positioned.one? && candidates == [positioned.first.id]
      return held(row, 'Fiches existantes à départager avant toute création ou réutilisation') unless
        (positioned.empty? && candidates.empty?) || reusable

      operation(row, season, reusable ? positioned.first : nil, references)
    end

    def operation(row, season, record, references)
      parts = SeriesTitles.parts(row.fetch('observed_title'))
      { 'kind' => record ? 'reuse_episode' : 'create_episode', 'existing_id' => record&.id,
        'season_id' => season&.id, 'season' => row['local_season'], 'episode' => row['local_episode'],
        'season_rank_before' => season&.rank,
        'french_title' => parts.size == 3 ? parts[1] : parts[0],
        'original_title' => parts.size == 3 ? parts[2] : nil, 'path' => row['path'],
        'observed_title' => row['observed_title'], 'references' => references }
    end

    def held(row, reason)
      { 'path' => row.fetch('path'), 'reason' => reason, 'candidate_ids' =>
        SeriesTitles.candidates(@index, row.fetch('observed_title')) }
    end
  end
end
