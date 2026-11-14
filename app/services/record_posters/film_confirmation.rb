# frozen_string_literal: true

require 'digest'

module RecordPosters
  # Confirmation is bound to one record and its current state; only artwork is stored.
  class FilmConfirmation
    class Error < StandardError; end

    PURPOSE = 'record-poster-film-confirmation'
    URL = %r{\Ahttps://www\.themoviedb\.org/movie/([1-9]\d*)(?:-[^/?#\s]+)?/?(?:\?[^#\s]*)?\z}
    POSTER_PATH = %r{\A/[a-zA-Z0-9]+\.(?:jpg|png|webp)\z}

    def self.supported?(record)
      record.record_kind == 'standalone_video' || (record.record_kind == 'undetermined' && !record.children.exists?)
    end

    def initialize(client: nil, download: ImageDownload.new, verifier: nil)
      @client = client || CatalogEnrichment::TmdbFilmClient.new(
        cache_dir: Rails.root.join('tmp/poster-confirmation-cache'), max_age: 1.hour
      )
      @download = download
      @verifier = verifier || Rails.application.message_verifier(PURPOSE)
    end

    def preview(record, url:)
      validate_record!(record)
      match = url.to_s.match(URL) if url.is_a?(String) && url.bytesize <= 1000
      raise Error, 'Indique un lien de film https://www.themoviedb.org/movie/…' unless match

      movie = @client.movie(id: match[1].to_i)
      raise Error, 'Aucune pochette proposée pour cette référence.' unless movie['poster_path'].to_s.match?(POSTER_PATH)

      data = confirmation_data(record, movie)
      signed = data.slice('record_id', 'snapshot', 'tmdb_movie_id', 'poster_path')
      data.merge('token' => @verifier.generate(signed, purpose: PURPOSE, expires_in: 15.minutes))
    end

    def confirm(record, token:)
      data = verified_data(record, token)
      bytes = @download.call(data.fetch('poster_path'))
      store_confirmed(record, data, bytes)
    end

    def preview_image(record, token:)
      data = verified_data(record, token)
      @download.call(data.fetch('poster_path'))
    end

    private

    def verified_data(record, token)
      data = @verifier.verified(token, purpose: PURPOSE) if token.is_a?(String) && token.bytesize <= 16_384
      raise Error, 'Confirmation invalide ou expirée : vérifie à nouveau la proposition.' unless data.is_a?(Hash)

      validate_confirmation!(record, data)
      data
    end

    def confirmation_data(record, movie)
      { 'record_id' => record.id, 'snapshot' => snapshot(record), 'tmdb_movie_id' => movie.fetch('id'),
        'title' => movie['title'], 'original_title' => movie['original_title'],
        'release_date' => movie['release_date'], 'overview' => movie['overview'],
        'poster_path' => movie['poster_path'] }
    end

    def validate_record!(record)
      raise Error, 'Cette fiche ne peut pas recevoir une pochette de film.' unless self.class.supported?(record)
    end

    def validate_confirmation!(record, data)
      validate_record!(record)
      raise Error, 'Cette confirmation concerne une autre fiche.' unless data['record_id'] == record.id
      unless data['snapshot'] == snapshot(record)
        raise Error, 'La fiche ou sa pochette a changé : vérifie à nouveau la proposition.'
      end

      id = data['tmdb_movie_id']
      raise Error, 'Référence de film invalide.' unless id.is_a?(Integer) && id.positive?
    end

    def snapshot(record)
      record.association(:record_poster).reset
      poster = record.record_poster
      blob_id = poster.image.blob.id if poster&.image&.attached?
      Digest::SHA256.hexdigest(ActiveSupport::JSON.encode([record.attributes, poster&.attributes, blob_id]))
    end

    def store_confirmed(record, data, bytes)
      Record.transaction do
        set_lock_timeout
        record.lock!
        lock_posters
        validate_confirmation!(record, data)
        Store.call(record, bytes: bytes, source: source(data), automatic: true, restore: true)
      end
    end

    def lock_posters
      return unless Record.connection.adapter_name == 'PostgreSQL'

      Record.connection.execute('LOCK TABLE record_posters IN SHARE ROW EXCLUSIVE MODE')
    end

    def set_lock_timeout
      return unless Record.connection.adapter_name == 'PostgreSQL'

      Record.connection.execute("SET LOCAL lock_timeout = '5s'")
    end

    def source(data)
      id = data.fetch('tmdb_movie_id')
      { 'kind' => 'tmdb', 'url' => "https://www.themoviedb.org/movie/#{id}", 'tmdb_movie_id' => id,
        'target' => { 'type' => 'movie', 'id' => id }, 'poster_path' => data.fetch('poster_path'),
        'retrieved_at' => Time.current.iso8601, 'identity_confirmation' => { 'origin' => 'user_confirmed_preview' } }
    end
  end
end
