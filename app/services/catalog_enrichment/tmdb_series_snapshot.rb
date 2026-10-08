# frozen_string_literal: true

require 'time'

module CatalogEnrichment
  # Separates translated metadata, original-language titles and reference dates.
  class TmdbSeriesSnapshot
    def initialize(client:, series_id:)
      @client = client
      @series_id = Integer(series_id)
      raise ArgumentError, 'Series ID must be positive' unless @series_id.positive?
    end

    def call
      series = @client.get("tv/#{@series_id}")
      raise ArgumentError, 'TMDB returned another series' unless series.fetch('id') == @series_id

      episodes = series.fetch('seasons').reject { |season| season.fetch('season_number').zero? }.flat_map do |season|
        season_episodes(season.fetch('season_number'), series.fetch('original_language'))
      end
      snapshot(series, episodes)
    end

    private

    def snapshot(series, episodes)
      {
        format: 'vidb.tmdb_series_snapshot', version: 1, read_only: true,
        retrieved_at: Time.now.utc.iso8601, tmdb_series_id: @series_id,
        source_url: "https://www.themoviedb.org/tv/#{@series_id}", language: 'fr-FR',
        series: series, episodes: episodes
      }
    end

    def season_episodes(number, original_language)
      path = "tv/#{@series_id}/season/#{number}"
      translated = @client.get(path)
      original = @client.get(path, language: original_language)
      raise ArgumentError, 'TMDB returned another season' unless translated.fetch('season_number') == number

      raise ArgumentError, 'Original-language season mismatch' unless original.fetch('season_number') == number

      combine_episodes(translated, original, number)
    end

    def combine_episodes(translated, original, number)
      originals = original.fetch('episodes').index_by { |episode| episode.fetch('id') }
      translated.fetch('episodes').map do |episode|
        episode_metadata(episode, originals.fetch(episode.fetch('id')), number)
      end
    end

    def episode_metadata(episode, original, season)
      {
        tmdb_episode_id: episode.fetch('id'), season_number: season,
        episode_number: episode.fetch('episode_number'), title_fr: episode.fetch('name'),
        title_original: original.fetch('name'), overview_fr: episode['overview'],
        first_air_date: episode['air_date'], reference_runtime_minutes: episode['runtime']
      }
    end
  end
end
