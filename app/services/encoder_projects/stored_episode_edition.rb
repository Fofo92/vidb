module EncoderProjects
  class StoredEpisodeEdition
    def initialize(links)
      @links = links
    end

    def mapped?
      @links.any? { |link| Array(link.evidence['external_parts']).size > 1 }
    end

    def call(numbers, rows)
      link = @links.find do |item|
        item.local_season_number == numbers.season && item.local_episode_number == numbers.episode
      end
      raise ArgumentError, 'Numérotation locale spécifique : sa source doit être consultée.' unless link

      ids = Array(link.evidence['external_parts']).pluck('episode_id')
      return ordinary_row(link, numbers, rows) if ids.empty?

      parts = rows.select { |row| ids.include?(row['tmdb_episode_id']) }
      raise ArgumentError, 'Parties du catalogue modifiées : vérifie la correspondance.' unless parts.size == ids.size

      [EpisodeEditionMapping.new.from_parts(numbers.episode, link.record.french_title,
                                            link.evidence.fetch('numbering_source'), parts)]
    end

    private

    def ordinary_row(link, numbers, rows)
      row = rows.find do |item|
        item['tmdb_episode_id'] == link.external_episode_id && item['episode_number'] == link.external_episode_number
      end
      raise ArgumentError, 'Identité catalogue modifiée : vérifie la correspondance.' unless row

      [row.merge('episode_number' => numbers.episode, 'external_episode_number' => link.external_episode_number,
                 'title_fr' => link.record.french_title)]
    end
  end
end
