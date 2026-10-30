module EncoderProjects
  # Preserves montage identity while explicitly targeting an episode in a local series.
  class LocalEpisodeChoice
    def self.call(record, project)
      series = series_for(record)
      return unless series

      numbers = episode_numbers(project)
      season = record.record_kind_season? ? (record.rank || numbers['season']) : numbers['season']
      target = numbers.merge('season' => season)
      { series: series, season: season, episode: target['episode'], project: project.merge('episode_target' => target) }
    end

    def self.series_for(record)
      return record if record.record_kind_series?

      record.parent if record.record_kind_season? && record.parent&.record_kind_series?
    end
    private_class_method :series_for

    def self.episode_numbers(project)
      request = EpisodeRequest.new(project)
      { 'season' => request.season, 'episode' => request.episode }
    rescue ArgumentError
      { 'season' => 1, 'episode' => 1 }
    end
    private_class_method :episode_numbers
  end
end
