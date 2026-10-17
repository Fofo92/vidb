# frozen_string_literal: true

module CatalogEnrichment
  class FilmSearchSnapshot
    MAX_PAGES = 20

    def initialize(client:)
      @client = client
    end

    def call(local:)
      titles = [local['french_title'], local['original_title']].filter_map(&:presence).uniq
      searches = titles.map { |title| collect(title) }
      { results: searches.flat_map { |search| search[:results] }.uniq { |film| film.fetch('id') },
        complete: searches.all? { |search| search[:complete] },
        queries: searches.map { |search| search.except(:results) } }
    end

    private

    def collect(title)
      first = @client.search(title: title, page: 1)
      count = first.fetch('total_pages')
      pages = [first] + (2..[count, MAX_PAGES].min).map { |page| @client.search(title: title, page: page) }
      { title: title, pages_read: pages.size, total_pages: count,
        complete: count <= MAX_PAGES && pages.all? { |page| page.fetch('total_pages') <= pages.size },
        results: pages.flat_map { |page| page.fetch('results') } }
    end
  end
end
