# frozen_string_literal: true

module RecordPosters
  class Fetch
    class Error < StandardError; end

    def initialize(client: nil, download: ImageDownload.new, film_target: nil)
      @client = client || TmdbClient.new(cache_dir: Rails.root.join('tmp/poster-cache'))
      @download = download
      @film_target = film_target
    end

    def call(record, restore: false)
      poster = record.record_poster
      return :preserved if poster && (poster.image.attached? || (poster.source['kind'] == 'manual' && !restore))

      target = resolve_target(record)
      return :unidentified unless target

      result = @client.poster(target)
      return :absent if result[:path].blank?

      Store.call(record, bytes: @download.call(result.fetch(:path)), automatic: true, restore: restore,
                         source: { 'kind' => 'tmdb', 'url' => result.fetch(:url), 'target' => target.stringify_keys,
                                   'retrieved_at' => Time.current.iso8601 })
    end

    private

    def resolve_target(record)
      target = Target.call(record)
      return target if target || !FilmTarget.searchable?(record)

      (@film_target ||= FilmTarget.new).call(record)
    end
  end
end
