# frozen_string_literal: true

module CatalogEnrichment
  # Local numbering and external identity are deliberately separate.
  class LocalTmdbMapping
    attr_reader :data, :episodes

    def initialize(data:, snapshot:)
      @data = data.deep_stringify_keys
      @snapshot = snapshot.deep_stringify_keys
      @episodes = @data.fetch('episodes')
      validate!
    end

    def external_episode(entry)
      @snapshot.fetch('episodes').find { |episode| episode.fetch('tmdb_episode_id') == entry.fetch('tmdb_episode_id') }
    end

    private

    def validate!
      unless @data['format'] == 'vidb.local_tmdb_episode_mapping' && @data['version'] == 1
        raise ArgumentError, 'Invalid local mapping format'
      end

      validate_snapshot!
      validate_uniqueness!
      @episodes.each { |entry| validate_episode!(entry) }
    end

    def validate_snapshot!
      valid = @snapshot['format'] == 'vidb.tmdb_series_snapshot' && @snapshot['version'] == 1 &&
              @snapshot['tmdb_series_id'] == @data.fetch('tmdb_series_id')
      raise ArgumentError, 'Snapshot does not match the selected series' unless valid
    end

    def validate_uniqueness!
      raise ArgumentError, 'Empty mapping' if @episodes.empty?

      identities = @episodes.map { |entry| entry.fetch('tmdb_episode_id') }
      numbers = @episodes.map { |entry| entry.values_at('local_season', 'local_episode') }
      records = @episodes.filter_map { |entry| entry.dig('expected_record', 'id') }
      return if [identities, numbers, records].all? { |values| values.uniq.length == values.length }

      raise ArgumentError, 'Duplicate local number, external ID or existing record'
    end

    def validate_episode!(entry)
      numbers = entry.values_at('local_season', 'local_episode', 'tmdb_season', 'tmdb_episode', 'tmdb_episode_id')
      unless numbers.all? { |number| number.is_a?(Integer) && number.positive? }
        raise ArgumentError, 'Positive integer identifiers required'
      end

      episode = external_episode(entry)
      valid = episode && episode['season_number'] == entry['tmdb_season'] &&
              episode['episode_number'] == entry['tmdb_episode'] && episode['title_original'] == entry['title_original']
      raise ArgumentError, 'External identity or original title changed; mapping requires review' unless valid
    end
  end
end
