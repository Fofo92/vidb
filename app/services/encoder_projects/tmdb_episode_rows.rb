module EncoderProjects
  class TmdbEpisodeRows
    def self.call(translated, original, season)
      originals = original.fetch('episodes').index_by { |row| row.fetch('id') }
      translated.fetch('episodes').map do |row|
        native = originals.fetch(row.fetch('id'))
        metadata(row, native, season)
      end
    end

    def self.metadata(row, native, season)
      raise ArgumentError, 'Numérotation originale différente' unless native['episode_number'] == row['episode_number']

      { 'tmdb_episode_id' => row.fetch('id'), 'season_number' => season,
        'episode_number' => row.fetch('episode_number'), 'title_fr' => row.fetch('name'),
        'title_original' => native.fetch('name'), 'overview_fr' => row['overview'],
        'first_air_date' => row['air_date'], 'reference_runtime_minutes' => row['runtime'] }
    end
  end
end
