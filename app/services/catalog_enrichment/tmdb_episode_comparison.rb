# frozen_string_literal: true

module CatalogEnrichment
  # Proposes evidence for review; a matching number alone never accepts a link.
  class TmdbEpisodeComparison
    def initialize(snapshot:, reconciliation:, directory:, catalogue: [])
      @snapshot = snapshot.deep_stringify_keys
      @report = reconciliation
      @directory = File.expand_path(directory)
      @catalogue = catalogue
      raise ArgumentError, 'Invalid snapshot' unless @snapshot['format'] == 'vidb.tmdb_series_snapshot'
      raise ArgumentError, 'Invalid reconciliation' unless @report['format'] == 'vidb.video_asset_reconciliation'
    end

    def call
      entries = @report.fetch('observations').select do |entry|
        entry.fetch('path').start_with?("#{@directory}/") && entry['type'] != 'directory'
      end
      observations = entries.map { |entry| compare(entry) }
      report_payload(observations)
    end

    private

    def report_payload(observations)
      {
        format: 'vidb.tmdb_episode_comparison', version: 1, read_only: true,
        tmdb_series_id: @snapshot.fetch('tmdb_series_id'), directory: @directory,
        source_inventory: @report.fetch('source_inventory'),
        summary: observations.group_by { |entry| entry[:status] }.transform_values(&:length),
        observations: observations
      }
    end

    def compare(entry)
      number = EpisodeFilenameTitle.parse(entry.fetch('stem'))
      result = { path: entry.fetch('path'), accepted: false }
      return result.merge(status: 'not_an_episode') unless number

      matches = title_matches(number.fetch(:title))
      result.merge(status: status(matches, number), local_season: number.fetch(:season),
                   local_episode: number.fetch(:episode), local_title: number.fetch(:title),
                   filename_evidence: number.slice(:raw_title, :language_marker, :ambiguous_part_suffix),
                   tmdb_candidates: matches, catalogue_candidates: catalogue_matches(matches))
    end

    def title_matches(title)
      titles = [title]
      split = title.match(/\A(.+?)\s+\((.+)\)\z/)
      titles.concat(split.captures) if split
      @snapshot.fetch('episodes').select do |episode|
        titles.any? { |value| episode_titles(episode).include?(normalize(value)) }
      end
    end

    def episode_titles(episode)
      %w[title_fr title_original].map { |key| normalize(episode[key]) }.reject(&:empty?)
    end

    def status(matches, number)
      return 'filename_suffix_requires_review' if number[:ambiguous_part_suffix]

      return 'title_unmatched' if matches.empty?
      return 'title_ambiguous' if matches.many?

      episode = matches.first
      agrees = episode['season_number'] == number.fetch(:season) && episode['episode_number'] == number.fetch(:episode)
      agrees ? 'title_and_number_agree' : 'title_number_conflict'
    end

    def catalogue_matches(matches)
      titles = matches.flat_map { |episode| episode_titles(episode) }
      @catalogue.select do |record|
        %w[french_title original_title].any? do |key|
          value = normalize(record[key])
          !value.empty? && titles.include?(value)
        end
      end
    end

    def normalize(title)
      title.to_s.unicode_normalize(:nfkc).downcase.tr('’', "'").gsub(/\s+/, ' ').strip
    end
  end
end
