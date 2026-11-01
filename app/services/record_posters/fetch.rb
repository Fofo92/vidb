# frozen_string_literal: true

module RecordPosters
  class Fetch
    class Error < StandardError; end

    def self.preserved?(poster, restore: false)
      return false unless poster
      return true if poster.source['kind'] == 'manual' && (!restore || poster.image.attached?)

      poster.image.attached? && !(poster.source['kind'] == 'tmdb' && poster.source['encoder_pending'].is_a?(Hash))
    end

    def initialize(client: nil, download: ImageDownload.new, film_target: nil)
      @client = client || TmdbClient.new(cache_dir: Rails.root.join('tmp/poster-cache'))
      @download = download
      @film_target = film_target
    end

    def call(record, restore: false)
      poster = record.record_poster
      return :preserved if self.class.preserved?(poster, restore: restore)

      target = resolve_target(record)
      return :unidentified unless target

      pending = poster && poster.source['encoder_pending'].deep_dup
      result = poster_result(target, pending)
      return :absent if result[:path].blank?

      save_poster(record, result, target, pending, restore)
    end

    private

    def save_poster(record, result, target, pending, restore)
      source = { 'kind' => 'tmdb', 'url' => result.fetch(:url), 'target' => target.stringify_keys,
                 'poster_path' => result.fetch(:path), 'retrieved_at' => Time.current.iso8601 }
      Store.call(record, bytes: @download.call(result.fetch(:path)), automatic: true,
                         restore: restore, refresh: pending, source: source)
    end

    def poster_result(target, pending)
      type = target.fetch(:type)
      key = type == 'movie' ? 'tmdb_movie_id' : 'tmdb_series_id'
      if pending.is_a?(Hash) && pending[key] == target[:id] && pending['poster_path'].present? && !target[:season]
        return { path: pending['poster_path'], url: "https://www.themoviedb.org/#{type}/#{target[:id]}" }
      end

      @client.poster(target)
    end

    def resolve_target(record)
      target = Target.call(record)
      return target if target || !FilmTarget.searchable?(record)

      (@film_target ||= FilmTarget.new).call(record)
    end
  end
end
