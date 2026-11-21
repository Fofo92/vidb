module EncoderProjects
  class RecordPresentation
    def self.call(record)
      record.attributes.slice('french_title', 'original_title', 'year', 'record_kind', 'abstract').merge(
        'language_version' => record.language_version.short_name,
        'reference_runtime_minutes' => record.length_in_mn,
        'original_language_evidence' => OriginalLanguage.call(record),
        'genres' => record.effective_genders.map(&:name), 'countries' => record.effective_countries.map(&:long_name)
      ).merge(episode_metadata(record)).merge(DestinationContainer.call(record))
    end

    def self.episode_metadata(record)
      placement = episode_placement(record)
      return placement if placement.empty?

      placement.merge('present_copy_versions' => present_copy_versions(record))
    end
    private_class_method :episode_metadata

    def self.episode_placement(record)
      return {} unless record.record_kind_episode? && record.parent&.record_kind_season?

      series = record.parent.parent
      return {} unless series&.record_kind_series?

      { 'season_number' => record.parent.rank, 'episode_number' => record.rank,
        'series_french_title' => series.french_title, 'series_original_title' => series.original_title,
        'series_year' => destination_series_year(series),
        'series_genres' => series.effective_genders.map(&:name),
        'series_countries' => series.effective_countries.map(&:long_name),
        'series_titles' => [series.french_title, series.original_title].compact_blank }
    end

    def self.present_copy_versions(record)
      record.video_assets.where(status: 'present').includes(:language_version).map do |copy|
        copy.language_version&.short_name || 'IND'
      end.uniq.sort
    end
    private_class_method :present_copy_versions

    def self.destination_series_year(series)
      series.year || series.descendants.where(record_kind: 'episode').minimum(:year)
    end
    private_class_method :destination_series_year
  end
end
