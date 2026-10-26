module EncoderProjects
  class EpisodeDefaults
    def self.call(series, numbers, candidate = {})
      season = existing_season(series, numbers)
      existing = season&.children&.find_by(record_kind: 'episode', rank: numbers.episode)
      values = candidate.merge('series_id' => series.id, 'season' => numbers.season, 'episode' => numbers.episode)
      values.merge(editorial(existing, numbers, candidate)).merge(references(existing || season || series, candidate))
            .merge(summary(existing, candidate))
    end

    def self.existing_season(series, numbers)
      seasons = series.children.where(record_kind: 'season', rank: numbers.season)
      seasons.sole if seasons.one?
    end

    def self.editorial(existing, numbers, candidate)
      { 'title' => existing&.french_title.presence || candidate['title'].presence || numbers.title,
        'original_title' => existing&.original_title.presence || candidate['original_title'],
        'previous_original_title' => existing&.original_title,
        'year' => existing&.year || candidate['year'],
        'existing_record_id' => existing&.id, 'language_version' => existing&.language_version&.short_name }
    end

    def self.summary(existing, candidate)
      return candidate.slice('abstract', 'abstract_source') unless existing&.abstract.present?
      if synopsis_upgrade?(existing, candidate)
        return candidate.slice('abstract', 'abstract_source').merge('previous_abstract' => existing.abstract,
                                                                    'replace_external_abstract' => true)
      end

      { 'abstract' => existing.abstract, 'abstract_source' => existing.abstract_provenance['source'],
        'abstract_notice' => candidate['abstract_notice'].presence ||
          'Résumé existant conservé ; toute correction reste à ta main.' }
    end

    def self.synopsis_upgrade?(existing, candidate)
      source = candidate['abstract_source'] || candidate['source']
      current = existing.abstract_provenance['source']
      !existing.abstract_protected? && candidate['abstract'].present? &&
        SynopsisPreference.rank(source) <= SynopsisPreference.rank(current)
    end

    def self.references(series, candidate)
      { 'gender_ids' => series.effective_genders.map(&:id).presence || candidate.fetch('gender_ids', []),
        'country_ids' => series.effective_countries.map(&:id).presence || candidate.fetch('country_ids', []) }
    end
  end
end
