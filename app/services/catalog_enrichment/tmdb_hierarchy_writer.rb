# frozen_string_literal: true

module CatalogEnrichment
  # Writes only a previously checked plan inside the caller's transaction.
  class TmdbHierarchyWriter
    def initialize(root:, plan:, mapping:)
      @root = root
      @plan = plan
      @mapping = mapping
    end

    def call
      @root.update!(record_kind: 'series')
      seasons = @plan.fetch('seasons').to_h { |item| [item.fetch('local_season'), write_season(item)] }
      @plan.fetch('episodes').map do |item|
        entry = item.fetch('local_mapping')
        record = write_episode(item, seasons.fetch(entry.fetch('local_season')))
        write_link(record, item)
      end
    end

    private

    def write_season(item)
      if item.fetch('action') == 'reuse_proposal'
        season = Record.find(item.fetch('candidates').sole.fetch('id'))
        season.update!(record_kind: 'season')
        return season
      end

      @root.children.create!(neutral_attributes.merge(
                               french_title: item.fetch('proposed_title'), record_kind: 'season',
                               rank: item.fetch('local_season')
                             ))
    end

    def write_episode(item, season)
      return reuse_episode(item, season) if item.fetch('action') == 'reuse_proposal'

      entry = item.fetch('local_mapping')
      season.children.create!(episode_attributes(entry, item))
    end

    def episode_attributes(entry, item)
      neutral_attributes.merge(french_title: entry.fetch('catalogue_title_fr'),
                               original_title: entry.fetch('catalogue_title_original', entry.fetch('title_original')),
                               record_kind: 'episode',
                               rank: entry.fetch('local_episode'), abstract: item['overview_fr'])
    end

    def reuse_episode(item, season)
      record = Record.find(item.fetch('candidates').sole.fetch('id'))
      record.parent = season
      record.record_kind = 'episode'
      record.rank = item.fetch('local_mapping').fetch('local_episode')
      record.abstract = item['overview_fr'] if record.abstract.blank?
      record.save!
      record
    end

    def neutral_attributes
      { language_version: @root.language_version, is_recorded: nil, is_available: nil,
        is_seen: nil, is_checked: false, countries: @root.countries.to_a, genders: @root.genders.to_a }
    end

    def write_link(record, item)
      entry = item.fetch('local_mapping')
      CatalogueEpisodeLink.create!(record: record, provider: 'tmdb',
                                   external_series_id: @mapping.data.fetch('tmdb_series_id'),
                                   external_episode_id: entry.fetch('tmdb_episode_id'),
                                   **number_attributes(entry), evidence: evidence(item))
    end

    def number_attributes(entry)
      { local_season_number: entry.fetch('local_season'), local_episode_number: entry.fetch('local_episode'),
        external_season_number: entry.fetch('tmdb_season'), external_episode_number: entry.fetch('tmdb_episode') }
    end

    def evidence(item)
      item.slice('local_mapping', 'overview_fr', 'first_air_date', 'reference_runtime_minutes').merge(
        'source' => 'TMDB', 'source_snapshot_retrieved_at' => @mapping.data['source_snapshot_retrieved_at'],
        'note' => 'Reference dates and runtimes; not production years or measured durations'
      )
    end
  end
end
