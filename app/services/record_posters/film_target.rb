# frozen_string_literal: true

module RecordPosters
  # Reuse the catalogue's film identity policy, rather than introduce a second matcher.
  class FilmTarget
    def self.searchable?(record)
      return false unless %w[standalone_video undetermined].include?(record.record_kind)
      return false if record.abstract.blank? || Evidence.ids(record, 'movie').any? || !valid_titles?(record)

      record.record_kind_standalone_video? || !record.children.exists?
    end

    def self.valid_titles?(record)
      titles = record.attributes.values_at('french_title', 'original_title').reject(&:blank?)
      titles.any? && titles.all? { |title| title.bytesize <= 300 && !title.match?(/[[:cntrl:]]/) }
    end

    def initialize(client: nil, comparison: CatalogEnrichment::FilmIdentityComparison.new)
      client ||= CatalogEnrichment::TmdbFilmClient.new(cache_dir: Rails.root.join('tmp/poster-film-cache'))
      @snapshot = CatalogEnrichment::FilmSearchSnapshot.new(client: client)
      @comparison = comparison
    end

    def call(record)
      return unless self.class.searchable?(record)

      local = record.attributes.slice('french_title', 'original_title', 'abstract', 'year')
      snapshot = @snapshot.call(local: local)
      return unless snapshot.fetch(:complete)

      identity = @comparison.call(local: local, results: snapshot.fetch(:results))
      { type: 'movie', id: identity.fetch(:tmdb_id) } if identity[:status] == 'candidate'
    end
  end
end
