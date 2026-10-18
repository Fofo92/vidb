module ReconciliationWorkbench
  class SeasonTitleAction
    def call(payload)
      payload.fetch('season_titles').each do |id, change|
        season = Record.find(id)
        verify!(season, payload.fetch('record_id'), change)
        before = season.attributes
        season.update!(french_title: change.fetch('after'))
        changed = before.keys.reject { |key| before[key] == season.attributes[key] }
        raise ArgumentError, 'Une autre métadonnée serait modifiée' unless
          (changed - %w[french_title updated_at]).empty?
      end
      { 'renamed_seasons' => payload.fetch('season_titles').size }
    end

    private

    def verify!(season, root_id, change)
      return if season.record_kind_season? && season.parent_id == root_id && season.rank == change.fetch('rank') &&
                season.french_title == change.fetch('before') &&
                change.fetch('before') == format('Saison %02d', season.rank) &&
                change.fetch('after') == "Saison #{season.rank}"

      raise ArgumentError, 'Titre ou placement de saison modifié'
    end
  end
end
