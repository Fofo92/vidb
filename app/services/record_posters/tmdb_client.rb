# frozen_string_literal: true

module RecordPosters
  class TmdbClient < CatalogEnrichment::TmdbClient
    def poster(target)
      path = "#{target.fetch(:type)}/#{target.fetch(:id)}"
      path += "/season/#{target[:season]}" if target[:season]
      payload = get(path)
      valid = target[:season] ? payload['season_number'] == target[:season] : payload['id'] == target[:id]
      raise Error, 'Identité TMDB différente de la fiche' unless valid

      { path: payload['poster_path'], url: "https://www.themoviedb.org/#{path}" }
    end

    private

    def validate_path!(path, language)
      valid = path.match?(%r{\A(?:tv/[1-9]\d*(?:/season/[1-9]\d*)?|(?:movie|collection)/[1-9]\d*)\z})
      return if valid && language.match?(/\A[a-z]{2}(?:-[A-Z]{2})?\z/)

      raise ArgumentError, 'Identifiant de pochette invalide'
    end
  end
end
