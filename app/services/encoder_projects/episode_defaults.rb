module EncoderProjects
  class EpisodeDefaults
    def self.call(series, numbers, candidate = {})
      existing = existing_episode(series, numbers)
      values = candidate.merge('series_id' => series.id, 'season' => numbers.season, 'episode' => numbers.episode)
      values.merge(editorial(existing, numbers, candidate)).merge(references(existing || series, candidate))
    end

    def self.existing_episode(series, numbers)
      seasons = series.children.where(record_kind: 'season', rank: numbers.season)
      seasons.one? ? seasons.sole.children.find_by(record_kind: 'episode', rank: numbers.episode) : nil
    end

    def self.editorial(existing, numbers, candidate)
      { 'title' => existing&.french_title.presence || candidate['title'].presence || numbers.title,
        'year' => existing&.year || candidate['year'],
        'abstract' => existing&.abstract.presence || candidate['abstract'],
        'existing_record_id' => existing&.id, 'language_version' => existing&.language_version&.short_name }
    end

    def self.references(series, candidate)
      { 'gender_ids' => series.effective_genders.map(&:id).presence || candidate.fetch('gender_ids', []),
        'country_ids' => series.effective_countries.map(&:id).presence || candidate.fetch('country_ids', []) }
    end
  end
end
