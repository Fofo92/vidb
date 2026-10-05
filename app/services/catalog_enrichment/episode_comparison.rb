# frozen_string_literal: true

module CatalogEnrichment
  # Compares publisher numbering with historical disk evidence without accepting links.
  class EpisodeComparison
    def initialize(reconciliation:, evidence:)
      @report = reconciliation
      @evidence = evidence
      @episodes = evidence.fetch('episodes')
      validate!
    end

    def call
      observations = relevant_observations.map { |entry| compare(entry) }
      {
        format: 'vidb.external_episode_comparison', version: 1, read_only: true,
        source_inventory: @report.fetch('source_inventory'), evidence: @evidence,
        summary: observations.group_by { |entry| entry[:status] }.transform_values(&:length),
        observations: observations
      }
    end

    private

    def validate!
      raise ArgumentError, 'Invalid reconciliation format' unless valid_reconciliation?
      raise ArgumentError, 'Invalid evidence format' unless valid_evidence?

      validate_episodes!
    end

    def valid_reconciliation?
      @report['format'] == 'vidb.video_asset_reconciliation'
    end

    def valid_evidence?
      @evidence['format'] == 'vidb.external_episode_evidence' && @evidence['version'] == 1
    end

    def validate_episodes!
      numbers = @episodes.map { |episode| episode.fetch('number') }
      valid = numbers.any? && numbers.uniq == numbers && numbers.all? { |number| positive_integer?(number) }
      raise ArgumentError, 'Episode numbers must be unique positive integers' unless valid

      raise ArgumentError, 'Episode titles must be nonempty strings' unless valid_titles?
    end

    def valid_titles?
      @episodes.all? { |episode| episode.fetch('title').is_a?(String) && !episode['title'].strip.empty? }
    end

    def positive_integer?(number)
      number.is_a?(Integer) && number.positive?
    end

    def relevant_observations
      @report.fetch('observations').select do |entry|
        entry.fetch('container_candidates', []).any? do |candidate|
          candidate['record_id'] == @evidence.fetch('target_record_id') &&
            normalize(candidate['french_title']) == normalize(@evidence.fetch('series_title'))
        end
      end
    end

    def compare(entry)
      prefix = entry.fetch('stem').match(/\A(?:S\d+\s*)?E(\d+)\s*(?:-\s*)?(.*)\z/i)
      result = { path: entry.fetch('path'), accepted: false }
      return result.merge(status: 'episode_number_unrecognized') unless prefix

      number = prefix[1].to_i
      title = prefix[2].strip
      by_number = @episodes.find { |episode| episode['number'] == number }
      result.merge(disk_number: number, disk_title: title, source_by_number: by_number,
                   **title_result(number, title))
    end

    def title_result(number, title)
      return { status: 'number_only_unverified', source_by_title: [] } if title.empty?

      matches = @episodes.select { |episode| normalize(episode.fetch('title')) == normalize(title) }
      { status: comparison_status(matches, number), source_by_title: matches }
    end

    def comparison_status(matches, number)
      return 'title_unmatched' if matches.empty?
      return 'title_ambiguous' if matches.length > 1

      matches.first['number'] == number ? 'title_and_number_agree' : 'title_number_conflict'
    end

    def normalize(title)
      title.to_s.unicode_normalize(:nfkc).downcase.gsub(/\s+/, ' ').strip
    end
  end
end
