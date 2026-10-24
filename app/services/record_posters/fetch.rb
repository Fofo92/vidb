# frozen_string_literal: true

module RecordPosters
  class Fetch
    class Error < StandardError; end

    def initialize(client: nil, download: ImageDownload.new)
      @client = client || TmdbClient.new(cache_dir: Rails.root.join('tmp/poster-cache'))
      @download = download
    end

    def call(record, restore: false)
      poster = record.record_poster
      return :preserved if poster && (poster.image.attached? || (poster.source['kind'] == 'manual' && !restore))

      target = Target.call(record)
      raise Error, 'Identification TMDB absente ou ambiguë ; ajoute une image manuellement' unless target

      result = @client.poster(target)
      return :absent if result[:path].blank?

      Store.call(record, bytes: @download.call(result.fetch(:path)), automatic: true, restore: restore,
                         source: { 'kind' => 'tmdb', 'url' => result.fetch(:url), 'target' => target.stringify_keys,
                                   'retrieved_at' => Time.current.iso8601 })
    end
  end
end
