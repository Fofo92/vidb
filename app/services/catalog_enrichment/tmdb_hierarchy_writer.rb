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
        abstract_result = enrich_abstract(record, item)
        write_link(record, item, abstract_result)
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
      season.children.create!(episode_attributes(entry))
    end

    def episode_attributes(entry)
      neutral_attributes.merge(french_title: entry.fetch('catalogue_title_fr'),
                               original_title: entry.fetch('catalogue_title_original', entry.fetch('title_original')),
                               record_kind: 'episode',
                               rank: entry.fetch('local_episode'))
    end

    def reuse_episode(item, season)
      record = Record.find(item.fetch('candidates').sole.fetch('id'))
      record.parent = season
      record.record_kind = 'episode'
      record.rank = item.fetch('local_mapping').fetch('local_episode')
      record.save!
      record
    end

    def neutral_attributes
      { language_version: @root.language_version, is_recorded: nil, is_available: nil,
        is_seen: nil, is_checked: false, countries: @root.countries.to_a, genders: @root.genders.to_a }
    end

    def enrich_abstract(record, item)
      source = { provider: 'tmdb', external_id: item.fetch('local_mapping').fetch('tmdb_episode_id'),
                 retrieved_at: @mapping.data['source_snapshot_retrieved_at'] }
      AbstractEnrichment.new(record: record, text: item['overview_fr'], source: source,
                             identity_confirmed: true).call(apply: true)
    end

    def write_link(record, item, abstract_result)
      entry = item.fetch('local_mapping')
      CatalogueEpisodeLink.create!(record: record, provider: 'tmdb',
                                   external_series_id: @mapping.data.fetch('tmdb_series_id'),
                                   external_episode_id: entry.fetch('tmdb_episode_id'),
                                   **number_attributes(entry), evidence: evidence(item).merge(
                                     'abstract_application' => abstract_result.slice(:status, :applied,
                                                                                     :editorial_validation_required)
                                   ))
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
