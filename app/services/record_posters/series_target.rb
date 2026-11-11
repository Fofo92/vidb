# frozen_string_literal: true

module RecordPosters
  # Identify artwork only; never create catalogue links or change editorial data.
  class SeriesTarget
    FIELDS = %i[id ancestry rank record_kind french_title original_title year updated_at].freeze

    def self.searchable?(record)
      record.record_kind == 'series' && Target.series_ids(record).empty? &&
        record.french_title.to_s.strip.present? && record.french_title.bytesize <= 300
    end

    def self.snapshot(record)
      [record.subtree.order(:id).pluck(*FIELDS), Target.series_ids(record)]
    end

    def initialize(client: nil)
      @client = client || EncoderProjects::TmdbSeriesClient.new(
        cache_dir: Rails.root.join('tmp/poster-series-cache'), max_age: 6.hours
      )
    end

    def call(record)
      return unless self.class.searchable?(record)

      episodes = local_episodes(record)
      return unless episodes && episodes.size >= 2

      matches = candidates(record).select { |row| supported?(row.fetch('id'), episodes) }
      { type: 'tv', id: matches.first.fetch('id') } if matches.one?
    end

    private

    def candidates(record)
      response = @client.search(title: record.french_title)
      return [] unless complete_search?(response)

      response.fetch('results').uniq { |row| row.fetch('id') }.select { |row| title_matches?(record, row) }
    end

    def local_episodes(record)
      seasons = record.children.order(:rank).to_a
      return unless valid_seasons?(seasons)

      branches = seasons.map { |season| [season, season.children.order(:rank).to_a] }
      return unless branches.all? { |_season, children| valid_children?(children) }

      branches.flat_map do |season, children|
        children.map { |child| child.attributes.merge('season' => season.rank) }
      end
    end

    def valid_seasons?(seasons)
      seasons.any? && seasons.size <= 20 && unique_ranks?(seasons) &&
        seasons.all? { |season| season.record_kind == 'season' }
    end

    def valid_children?(children)
      children.any? && unique_ranks?(children) && children.all? { |child| valid_episode?(child) }
    end

    def valid_episode?(child)
      child.record_kind == 'episode' && !child.has_children? && child.year.is_a?(Integer) &&
        child.year.between?(1900, Date.current.year)
    end

    def unique_ranks?(records)
      ranks = records.map(&:rank)
      ranks.all? { |number| number.is_a?(Integer) && number.positive? } && ranks.uniq.size == ranks.size
    end

    def complete_search?(response)
      rows = response.fetch('results')
      response['page'] == 1 && response['total_pages'] == 1 && rows.size <= 20 &&
        response['total_results'] == rows.size
    end

    def title_matches?(record, candidate)
      names = candidate.values_at('name', 'original_name').map { |name| SeriesEpisodeEvidence.key(name) }
      return false unless names.include?(SeriesEpisodeEvidence.key(record.french_title))
      return true if record.original_title.blank?

      SeriesEpisodeEvidence.key(record.original_title) == SeriesEpisodeEvidence.key(candidate['original_name'])
    end

    def supported?(id, episodes)
      return false unless id.is_a?(Integer) && id.positive?

      payload = @client.get("tv/#{id}")
      return false unless payload.fetch('id') == id

      SeriesEpisodeEvidence.new(client: @client, series_id: id,
                                language: payload.fetch('original_language')).call(episodes)
    end
  end
end
