# frozen_string_literal: true

module CatalogEnrichment
  # Builds a live, read-only plan. Creation proposals are never database writes.
  class TmdbHierarchyPlan
    def initialize(mapping:, snapshot:, catalogue:)
      @mapping = LocalTmdbMapping.new(data: mapping, snapshot: snapshot)
      @catalogue = catalogue.map(&:deep_stringify_keys)
      @root = @catalogue.find { |record| record['id'] == @mapping.data.fetch('root_record_id') }
    end

    def call
      validate_root!
      episodes = @mapping.episodes.map { |entry| episode_plan(entry) }
      seasons = @mapping.episodes.map { |entry| entry.fetch('local_season') }.uniq.sort.map { |n| season_plan(n) }
      payload(episodes, seasons)
    end

    private

    def validate_root!
      valid = @root && @root['french_title'] == @mapping.data['series_title'] && @root['ancestry'].blank? &&
              %w[undetermined series].include?(@root['record_kind'])
      raise ArgumentError, 'Series root changed or missing' unless valid
    end

    def payload(episodes, seasons)
      {
        format: 'vidb.tmdb_hierarchy_plan', version: 1, read_only: true,
        root: @root, proposed_root_kind: 'series', tmdb_series_id: @mapping.data['tmdb_series_id'],
        summary: episodes.group_by { |entry| entry[:action] }.transform_values(&:length),
        seasons: seasons, episodes: episodes
      }
    end

    def season_plan(number)
      matches = @catalogue.select do |record|
        record['ancestry'] == @root['id'].to_s && season_candidate?(record, number)
      end
      { local_season: number, action: season_action(matches), candidates: matches,
        proposed_title: format('Saison %<number>02d', number: number) }
    end

    def season_candidate?(record, number)
      record['rank'] == number || record['french_title'].to_s.match?(/\ASaison\s+0*#{number}\z/i)
    end

    def season_action(matches)
      return 'create_proposal' if matches.empty?

      return 'needs_review' unless matches.one? && %w[undetermined season].include?(matches.first['record_kind'])

      'reuse_proposal'
    end

    def episode_plan(entry)
      candidates = candidates_for(entry)
      action = episode_action(entry, candidates)
      external = @mapping.external_episode(entry)
      { local_mapping: entry, action: action, candidates: candidates,
        proposed_kind: 'episode', overview_fr: external['overview_fr'],
        first_air_date: external['first_air_date'], reference_runtime_minutes: external['reference_runtime_minutes'] }
    end

    def candidates_for(entry)
      titles = [entry['catalogue_title_fr'], entry['title_original'], @mapping.external_episode(entry)['title_fr']]
      normalized = titles.map { |title| normalize(title) }.reject(&:empty?)
      @catalogue.select do |record|
        %w[french_title original_title].any? { |key| normalized.include?(normalize(record[key])) }
      end
    end

    def episode_action(entry, candidates)
      expected = entry['expected_record']
      return candidates.empty? ? 'create_proposal' : 'needs_review' unless expected
      return 'needs_review' unless candidates.one? && expected.all? { |key, value| candidates.first[key] == value }

      valid_existing_episode?(candidates.first, entry) ? 'reuse_proposal' : 'needs_review'
    end

    def valid_existing_episode?(record, entry)
      season = season_plan(entry.fetch('local_season'))[:candidates]
      permitted = [nil, '', *season.map { |parent| "#{@root['id']}/#{parent['id']}" }]
      permitted.include?(record['ancestry']) && %w[undetermined episode].include?(record['record_kind']) &&
        @catalogue.none? { |child| child['ancestry'].to_s.split('/').include?(record['id'].to_s) }
    end

    def normalize(title)
      title.to_s.unicode_normalize(:nfkc).downcase.tr('’', "'").gsub(/\s+/, ' ').strip
    end
  end
end
