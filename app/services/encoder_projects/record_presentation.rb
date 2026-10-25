module EncoderProjects
  class RecordPresentation
    def self.call(record)
      record.attributes.slice('french_title', 'original_title', 'year', 'record_kind', 'abstract').merge(
        'language_version' => record.language_version.short_name,
        'genres' => record.effective_genders.map(&:name), 'countries' => record.effective_countries.map(&:long_name)
      ).merge(episode_placement(record))
    end

    def self.episode_placement(record)
      return {} unless record.record_kind_episode? && record.parent&.record_kind_season?

      series = record.parent.parent
      return {} unless series&.record_kind_series?

      { 'season_number' => record.parent.rank, 'episode_number' => record.rank,
        'series_titles' => [series.french_title, series.original_title].compact_blank }
    end
  end
end
