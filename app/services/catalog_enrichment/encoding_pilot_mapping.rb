# frozen_string_literal: true

module CatalogEnrichment
  # A title and number must agree before preparing a local/external identity.
  class EncodingPilotMapping
    def initialize(comparison:, inventory:, catalogue:, root_record_id:, now: Time.current)
      @comparison = comparison.deep_stringify_keys
      @files = inventory.deep_stringify_keys.fetch('entries').index_by { |entry| entry.fetch('path') }
      @catalogue = catalogue.map(&:deep_stringify_keys)
      @root_id = root_record_id
      @now = now
    end

    def call
      entries = @comparison.fetch('observations').map { |item| inspect_entry(item) }
      mark_duplicate_numbers(entries)
      { entries: entries, episodes: entries.filter_map { |entry| entry[:mapping] },
        counts: entries.group_by { |entry| entry[:status] }.transform_values(&:count) }
    end

    private

    def inspect_entry(item)
      result = { path: item.fetch('path'), status: item.fetch('status') }
      file = @files.fetch(item.fetch('path'))
      pending = pending_status(item, file)
      return result.merge(status: pending) if pending
      return result unless item['status'] == 'title_and_number_agree'

      result.merge(status: 'mapping_proposal', mapping: mapping(item, file))
    end

    def pending_status(item, file)
      return 'excluded_workspace' if workspace?(item.fetch('path'))
      return 'awaiting_stability' if Time.iso8601(file.fetch('modified_at')) > (@now - 24.hours)
      return unless item['local_season']
      return 'season_directory_conflict' unless season_directory_agrees?(item)

      nil
    end

    def season_directory_agrees?(item)
      parent = File.basename(File.dirname(item.fetch('path')))
      match = /\A(?:Saison|Season)\s+(\d+)\b/i.match(parent)
      match && match[1].to_i == item.fetch('local_season')
    end

    def workspace?(path)
      path.split('/').any? { |part| part.start_with?('video_encoder_') && part.end_with?('_workspace') }
    end

    def mapping(item, file)
      external = item.fetch('tmdb_candidates').sole
      entry = mapping_details(item, external, file)
      record = existing_record(item)
      entry[:expected_record] = record if record
      entry
    end

    def mapping_details(item, external, file)
      numbers(item, external).merge(
        titles(external),
        observed_path: item.fetch('path'),
        observed_size: file.fetch('size'),
        observed_modified_at: file['modified_at'],
        mapping_basis: 'explicit_series_title_and_number_agreement'
      )
    end

    def numbers(item, external)
      { local_season: item.fetch('local_season'), local_episode: item.fetch('local_episode'),
        tmdb_episode_id: external.fetch('tmdb_episode_id'), tmdb_season: external.fetch('season_number'),
        tmdb_episode: external.fetch('episode_number') }
    end

    def titles(external)
      { catalogue_title_fr: external.fetch('title_fr'), title_original: external.fetch('title_original') }
    end

    def existing_record(item)
      ids = item.fetch('catalogue_candidates').pluck('id')
      matches = @catalogue.select do |record|
        ids.include?(record['id']) && record['ancestry'].to_s.split('/').include?(@root_id.to_s)
      end
      matches.sole if matches.one?
    end

    def mark_duplicate_numbers(entries)
      proposed = entries.select { |entry| entry[:mapping] }
      groups = proposed.group_by { |entry| entry[:mapping].values_at(:local_season, :local_episode) }
      groups.each_value do |items|
        next if items.one?

        items.each do |entry|
          entry.delete(:mapping)
          entry[:status] = 'multiple_copies_require_review'
        end
      end
    end
  end
end
