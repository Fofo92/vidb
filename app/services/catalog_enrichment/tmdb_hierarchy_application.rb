# frozen_string_literal: true

module CatalogEnrichment
  # Locks the catalogue, rechecks the plan and applies all records and links atomically.
  class TmdbHierarchyApplication
    COLUMNS = %w[id french_title original_title record_kind ancestry rank]

    def initialize(mapping:, snapshot:, plan:)
      @mapping = LocalTmdbMapping.new(data: mapping, snapshot: snapshot)
      @snapshot = snapshot.deep_stringify_keys
      @plan = plan.deep_stringify_keys
    end

    def call(apply: false)
      Record.transaction do
        Record.connection.execute('LOCK TABLE records, catalogue_episode_links IN SHARE ROW EXCLUSIVE MODE')
        locked_call(apply)
      end
    end

    private

    def locked_call(apply)
      root = Record.find(@mapping.data.fetch('root_record_id'))
      existing = existing_links
      return receipt(existing, false, 'already_applied') if exact_rerun?(root, existing)

      validate_current!(existing)
      raise ArgumentError, 'Root language version missing' unless root.language_version

      links = apply ? TmdbHierarchyWriter.new(root: root, plan: @plan, mapping: @mapping).call : []
      receipt(links, apply, apply ? 'applied' : 'preview')
    end

    def existing_links
      CatalogueEpisodeLink.where(provider: 'tmdb', external_episode_id: @mapping.episodes.pluck('tmdb_episode_id')).to_a
    end

    def validate_current!(existing)
      raise ArgumentError, 'Partial or conflicting external links already exist' if existing.any?

      catalogue = Record.pluck(*COLUMNS).map { |values| COLUMNS.zip(values).to_h }
      current = TmdbHierarchyPlan.new(mapping: @mapping.data, snapshot: @snapshot, catalogue: catalogue).call
      validate_plan!(current)
    end

    def validate_plan!(current)
      unless current.deep_stringify_keys == @plan
        raise ArgumentError, 'Catalogue changed since preview; regenerate the plan'
      end

      actions = @plan.fetch('episodes') + @plan.fetch('seasons')
      return unless actions.any? { |item| item['action'] == 'needs_review' }

      raise ArgumentError, 'Unresolved proposals; no records changed'
    end

    def exact_rerun?(root, links)
      return false unless links.length == @mapping.episodes.length && root.record_kind == 'series'

      @mapping.episodes.all? do |entry|
        link = links.find { |item| item.external_episode_id == entry.fetch('tmdb_episode_id') }
        matching_link?(link, entry, root)
      end
    end

    def matching_link?(link, entry, root)
      record = link.record
      matching_numbers?(link, entry) && link.external_series_id == @mapping.data['tmdb_series_id'] &&
        record.record_kind == 'episode' && record.rank == entry['local_episode'] &&
        valid_parent?(record.parent, entry, root)
    end

    def matching_numbers?(link, entry)
      numbers = entry.values_at('local_season', 'local_episode', 'tmdb_season', 'tmdb_episode')
      actual = link.attributes.values_at('local_season_number', 'local_episode_number',
                                         'external_season_number', 'external_episode_number')
      numbers == actual
    end

    def valid_parent?(season, entry, root)
      season && season.record_kind == 'season' && season.rank == entry['local_season'] && season.parent_id == root.id
    end

    def receipt(links, applied, status)
      { applied: applied, status: status, root_record_id: @mapping.data['root_record_id'],
        summary: @plan.fetch('summary'), links: links.map { |link| link.attributes.except('evidence') } }
    end
  end
end
