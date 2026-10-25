module EncoderProjects
  class RecordPresentation
    def self.call(record)
      record.attributes.slice('french_title', 'original_title', 'year', 'record_kind', 'abstract').merge(
        'genres' => record.genders.map(&:name), 'countries' => record.countries.map(&:long_name)
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
