# frozen_string_literal: true

module RecordPosters
  # Fully enumerate the known release year before falling back to a broad search.
  class FilmSearch
    class YearClient
      def initialize(client, year)
        @client = client
        @year = year
      end

      def search(title:, page: 1)
        @client.search_for_year(title: title, year: @year, page: page)
      end
    end

    def initialize(client:)
      @client = client
    end

    def call(local:)
      scoped = year_snapshot(local)
      return scoped if supported?(local, scoped)

      CatalogEnrichment::FilmSearchSnapshot.new(client: @client).call(local: local)
    end

    private

    def year_snapshot(local)
      year = local['year']
      return unless year.is_a?(Integer) && year.between?(1000, 2999) && @client.respond_to?(:search_for_year)

      client = YearClient.new(@client, year)
      snapshot = CatalogEnrichment::FilmSearchSnapshot.new(client: client).call(local: local)
      results = snapshot.fetch(:results).select { |row| row['release_date'].to_s.start_with?("#{year}-") }
      snapshot.merge(results: results)
    end

    def supported?(local, snapshot)
      return false unless snapshot && snapshot[:complete]

      comparison = FilmPosterComparison.new.call(local: local, results: snapshot.fetch(:results))
      comparison.fetch(:comparisons).any? { |row| row[:supported] }
    end
  end
end
