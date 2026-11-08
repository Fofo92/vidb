module EncoderProjects
  class DvdMenuCatalogue
    LIMIT = 1000

    def initialize(series)
      @series = series
    end

    def call
      seasons = @series.children.where(record_kind: 'season').index_by(&:id)
      episodes = @series.descendants.where(record_kind: 'episode').order(:id).limit(LIMIT + 1).to_a
      raise ArgumentError, 'Catalogue DVD trop volumineux' if episodes.size > LIMIT

      { series_title: @series.french_title.presence || @series.original_title,
        episodes: episodes.filter_map { |episode| entry(episode, seasons[episode.parent_id]) } }
    end

    private

    def entry(episode, season)
      return unless season&.rank && season.rank >= 0 && episode.rank&.positive?

      { record_id: episode.id, season: season.rank, episode: episode.rank,
        french_title: episode.french_title, original_title: episode.original_title }
    end
  end
end
