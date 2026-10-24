# frozen_string_literal: true

module RecordPosters
  # Read the sources already retained by enrichment, including nested workbench receipts.
  class Evidence
    TYPES = { 'tv' => %w[tmdb_series_id external_series_id],
              'movie' => %w[tmdb_movie_id], 'collection' => %w[tmdb_collection_id] }.freeze

    def self.ids(record, type)
      values = [record.year_evidence, record.abstract_provenance, record.genre_provenance]
      new(type).ids(values).uniq
    end

    def initialize(type)
      @type = type
    end

    def ids(value)
      case value
      when Array then value.flat_map { |item| ids(item) }
      when Hash then own_ids(value) + value.values.flat_map { |item| ids(item) }
      else []
      end
    end

    private

    def own_ids(value)
      explicit = value.values_at(*TYPES.fetch(@type)).filter_map { |id| positive_id(id) }
      urls = value.values_at('url', 'source', 'source_url').filter_map do |url|
        match = url.to_s.match(%r{\Ahttps://www\.themoviedb\.org/#{@type}/([1-9]\d*)(?:[/?].*)?\z})
        match[1].to_i if match
      end
      explicit + urls
    end

    def positive_id(value)
      value.to_s.to_i if value.to_s.match?(/\A[1-9]\d*\z/)
    end
  end
end
