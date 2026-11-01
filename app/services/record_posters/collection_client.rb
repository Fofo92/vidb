# frozen_string_literal: true

module RecordPosters
  # Read explicit film membership and verify it against the collection's own catalogue.
  class CollectionClient < TmdbClient
    def movie(id)
      verified("movie/#{id}", id)
    end

    def collection(id)
      payload = verified("collection/#{id}", id)
      raise Error, 'Catalogue de collection TMDB absent' unless payload['parts'].is_a?(Array)

      payload
    end

    private

    def verified(path, id)
      payload = get(path)
      raise Error, 'Identité TMDB différente de la demande' unless payload['id'] == id

      payload
    end
  end
end
