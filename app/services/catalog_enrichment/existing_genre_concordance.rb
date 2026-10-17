# frozen_string_literal: true

module CatalogEnrichment
  # Corroborates the existing selection; never imports or truncates a source's list.
  class ExistingGenreConcordance
    def call(current:, external:, review_flags: [])
      return review('Specific classification requires documented examination', review_flags) if review_flags.any?
      return review('One or two existing genres required') unless valid_selection?(current)
      return review('Documentary category requires examination') if external.any? { |genre| genre['id'] == 99 }

      available = mapped_genres(external)
      missing = current - available
      return review('Some existing genres lack support', [], missing) if missing.any?

      { status: 'corroborated', retained_genres: current, supported_genres: available,
        unused_external_genres: available - current, changed: false,
        policy: 'existing_selection_supported_v1' }
    end

    private

    def valid_selection?(genres)
      genres.is_a?(Array) && genres.size.between?(1, 2) && genres == genres.uniq.sort &&
        genres.all? { |name| name.is_a?(String) && name.present? }
    end

    def mapped_genres(external)
      external.filter_map { |genre| FilmMetadataProposal::GENRES[genre['id']] }.uniq.sort
    end

    def review(reason, flags = [], missing = [])
      { status: 'needs_review', reason: reason, review_flags: flags, unsupported_genres: missing,
        changed: false, policy: 'existing_selection_supported_v1' }
    end
  end
end
