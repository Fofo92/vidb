module EncoderProjects
  # Retain a confirmed catalogue identity without changing editorial record fields.
  class PosterIdentityImport
    def self.call(record, candidate)
      new(record, candidate).call
    end

    def initialize(record, candidate)
      @record = record.record_kind == 'episode' ? record.parent&.parent : record
      @candidate = candidate
    end

    def call
      type = { 'standalone_video' => 'movie', 'series' => 'tv' }[@record&.record_kind]
      return :unidentified unless type

      ids = RecordPosters::Evidence.new(type).ids(@candidate.slice(
                                                    'source', 'additional_sources', 'poster_source'
                                                  )).uniq
      return :unidentified unless ids.one?
      return :conflict unless (RecordPosters::Evidence.ids(@record, type) + ids).uniq.one?

      save_reference(reference(type, ids.first))
    end

    private

    def reference(type, id)
      key = type == 'movie' ? 'tmdb_movie_id' : 'tmdb_series_id'
      { key => id, 'url' => "https://www.themoviedb.org/#{type}/#{id}",
        'poster_path' => valid_path(@candidate['poster_path']) }
    end

    def valid_path(path)
      path if path.is_a?(String) && path.bytesize <= 200 && path.match?(%r{\A/[a-zA-Z0-9]+\.(?:jpg|png|webp)\z})
    end

    def save_reference(reference)
      poster = RecordPoster.create_or_find_by!(record_id: @record.id)
      poster.with_lock do
        return :preserved if poster.source['kind'] == 'manual'
        return :preserved if unchanged?(poster, reference)

        source = poster.source.merge('encoder_pending' => reference)
        source['kind'] ||= 'catalogue'
        poster.update!(source: source)
      end
      @record.association(:record_poster).reset
      :scheduled
    end

    def unchanged?(poster, reference)
      return true if poster.source['encoder_pending'] == reference
      return false unless poster.image.attached? && poster.source['kind'] == 'tmdb'

      poster.source['url'] == reference['url'] && poster.source['poster_path'] == reference['poster_path']
    end
  end
end
