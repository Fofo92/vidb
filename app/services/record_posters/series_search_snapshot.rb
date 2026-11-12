# frozen_string_literal: true

module RecordPosters
  class SeriesSearchSnapshot
    MAX_PAGES = EncoderProjects::TmdbSeriesClient::MAX_SEARCH_PAGES

    def initialize(client:)
      @client = client
    end

    def call(title:)
      first = @client.search(title: title, page: 1)
      count = first['total_pages']
      total = first['total_results']
      return incomplete unless valid_totals?(count, total)

      pages = [first] + (2..count).map { |page| @client.search(title: title, page: page) }
      return incomplete unless valid_pages?(pages, count, total)

      results = pages.flat_map { |page| page.fetch('results') }
      complete = results.size == total && results.map { |row| row.fetch('id') }.uniq.size == total
      { complete: complete, results: complete ? results : [] }
    end

    private

    def valid_totals?(pages, total)
      pages.is_a?(Integer) && pages.between?(0, MAX_PAGES) && total.is_a?(Integer) &&
        total.between?(0, MAX_PAGES * 20) && (pages.positive? || total.zero?)
    end

    def valid_pages?(pages, count, total)
      pages.each_with_index.all? do |page, index|
        page['page'] == index + 1 && page['total_pages'] == count && page['total_results'] == total &&
          valid_rows?(page['results'])
      end
    end

    def valid_rows?(rows)
      rows.is_a?(Array) && rows.size <= 20 && rows.all? do |row|
        row.is_a?(Hash) && row['id'].is_a?(Integer) && row['id'].positive?
      end
    end

    def incomplete
      { complete: false, results: [] }
    end
  end
end
