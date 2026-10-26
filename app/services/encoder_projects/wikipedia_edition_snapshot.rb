module EncoderProjects
  class WikipediaEditionSnapshot
    def initialize(wikipedia: WikipediaClient.new)
      @wikipedia = wikipedia
    end

    def call(snapshot, candidate)
      source = candidate&.fetch('numbering_source', nil) || candidate&.fetch('source', nil)
      return snapshot unless source&.fetch('numbering_basis', nil) == 'season_ordered_list'

      page = @wikipedia.page(source.fetch('page_title'))
      raise ArgumentError, 'La page de numérotation a changé : recharge les propositions.' unless
        page.fetch('title') == source.fetch('page_title')

      data = snapshot.deep_stringify_keys
      data['episodes'] = mapped_episodes(data.fetch('episodes'), page)
      verify_selected!(data, candidate)
      data
    end

    private

    def mapped_episodes(rows, page)
      rows.group_by { |row| row.fetch('season_number') }.flat_map do |season, episodes|
        local = WikipediaSeasonEpisode.new.entries(page, season)
        map_season(episodes, local, season)
      end
    end

    def map_season(episodes, local, season)
      EpisodeEditionMapping.new.call(episodes, local)
    rescue ArgumentError => e
      raise ArgumentError, "Saison #{season} : #{e.message}"
    end

    def verify_selected!(data, candidate)
      row = data.fetch('episodes').find do |item|
        item['season_number'] == candidate['season'] && item['episode_number'] == candidate['episode']
      end
      return unless row && row.fetch('external_parts', []).size > 1

      expected = candidate.fetch('external_parts', []).pluck('episode_id')
      return if expected == row.fetch('external_parts').pluck('episode_id')

      raise ArgumentError, 'Le découpage proposé a changé : recharge et confirme la correspondance des parties.'
    end
  end
end
