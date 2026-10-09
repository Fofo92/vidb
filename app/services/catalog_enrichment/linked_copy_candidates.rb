# frozen_string_literal: true

module CatalogEnrichment
  # Checks confirmed external links and the historical file evidence independently.
  class LinkedCopyCandidates
    attr_reader :entries

    def initialize(evidence)
      @evidence = evidence
      @entries = evidence.fetch('copies').map(&:deep_symbolize_keys)
      validate!
    end

    def records
      root = Record.find(@evidence.fetch('root_record_id'))
      raise ArgumentError, 'Series hierarchy missing' unless root.record_kind == 'series'

      [root, *root.descendants.to_a]
    end

    def owner(entry)
      link = CatalogueEpisodeLink.find_by!(provider: 'tmdb', external_episode_id: entry.fetch(:tmdb_episode_id))
      validate_link!(link, entry)
      link.record
    end

    private

    def validate!
      valid = @evidence['format'] == 'vidb.linked_episode_completion' && @evidence['version'] == 1 &&
              @entries.any? && @entries.size == @evidence.fetch('total')
      paths = @entries.pluck(:path)
      ids = @entries.pluck(:tmdb_episode_id)
      valid &&= paths.uniq.size == paths.size && ids.uniq.size == ids.size
      raise ArgumentError, 'Invalid linked completion batch' unless valid

      @entries.each { |entry| validate_path!(entry) }
    end

    def validate_path!(entry)
      path = entry.fetch(:path)
      directory = @evidence.fetch('directory')
      valid = directory.start_with?('/videos/') && path.start_with?("#{directory}/") &&
              Pathname.new(path).cleanpath.to_s == path && !path.include?('_workspace/')
      valid &&= Time.iso8601(entry.fetch(:modified_at)) < Time.current - 24.hours
      raise ArgumentError, "Unsafe or recently modified file: #{path}" unless valid
    end

    def validate_link!(link, entry)
      record = link.record
      valid = link.external_series_id == @evidence.fetch('tmdb_series_id') &&
              link.local_season_number == entry.fetch(:local_season) &&
              link.local_episode_number == entry.fetch(:local_episode)
      valid &&= record.record_kind == 'episode' && record.rank == entry.fetch(:local_episode) &&
                valid_season?(record.parent, entry) && !record.has_children?
      raise ArgumentError, "Episode link changed: #{link.id}" unless valid
    end

    def valid_season?(season, entry)
      season && season.record_kind == 'season' && season.rank == entry.fetch(:local_season) &&
        season.parent_id == @evidence.fetch('root_record_id')
    end
  end
end
