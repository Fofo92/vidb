# frozen_string_literal: true

module RecordPosters
  class Fetch
    class Error < StandardError; end

    def self.preserved?(poster, restore: false)
      return false unless poster
      return true if poster.source['kind'] == 'manual' && (!restore || poster.image.attached?)

      poster.image.attached? && !(poster.source['kind'] == 'tmdb' && poster.source['encoder_pending'].is_a?(Hash))
    end

    def initialize(client: nil, download: ImageDownload.new, film_target: nil, series_target: nil)
      @client = client || TmdbClient.new(cache_dir: Rails.root.join('tmp/poster-cache'), max_age: 6.hours)
      @download = download
      @film_target = film_target
      @series_target = series_target
    end

    def call(record, restore: false)
      @series_snapshot = nil
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
      bytes = @download.call(result.fetch(:path))
      return store(record, bytes, source, pending, restore) unless @series_snapshot

      Record.transaction do
        lock_series_identity
        raise Error, 'La série a changé depuis son identification' unless
          SeriesTarget.snapshot(record.reload) == @series_snapshot

        store(record, bytes, source, pending, restore)
      end
    end

    def store(record, bytes, source, pending, restore)
      Store.call(record, bytes: bytes, automatic: true, restore: restore, refresh: pending, source: source)
    end

    def lock_series_identity
      return unless Record.connection.adapter_name == 'PostgreSQL'

      Record.connection.execute("SET LOCAL lock_timeout = '5s'")
      Record.connection.execute('LOCK TABLE records, catalogue_episode_links IN SHARE ROW EXCLUSIVE MODE')
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
      return target if target

      if SeriesTarget.searchable?(record)
        @series_snapshot = SeriesTarget.snapshot(record)
        return (@series_target ||= SeriesTarget.new).call(record)
      end
      return unless FilmTarget.searchable?(record)

      (@film_target ||= FilmTarget.new).call(record)
    end
  end
end
