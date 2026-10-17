# frozen_string_literal: true

module CatalogEnrichment
  # Explicit reviewed pairs, with shared named evidence; never relaxes the global matcher.
  class ReviewedFilmIdentity
    def call(local:, movie:, review:)
      raise ArgumentError, 'Reviewed TMDB identity changed' unless movie.fetch('id') == review.fetch('tmdb_id')

      validate_titles!(local, movie)
      validate_synopses!(local, movie, review.fetch('anchors'))

      { tmdb_id: movie.fetch('id'), supported: true, policy: 'reviewed_named_evidence_v1',
        title: movie['title'], original_title: movie['original_title'],
        shared_anchors: review.fetch('anchors'), review_reason: review.fetch('reason') }
    end

    private

    def validate_titles!(local, movie)
      local_titles = [local['french_title'], local['original_title']].map { |title| tokens(title) }.reject(&:empty?)
      external_titles = [movie['title'], movie['original_title']].map { |title| tokens(title) }.reject(&:empty?)
      raise ArgumentError, 'Reviewed title changed' unless local_titles.intersect?(external_titles)
    end

    def validate_synopses!(local, movie, anchors)
      evidence = [tokens(local['abstract']), tokens(movie['overview'])]
      unless anchors.size >= 2 && anchors.all? { |word| tokens(word) == [word] } &&
             evidence.all? { |words| (anchors - words).empty? }
        raise ArgumentError, 'Reviewed synopsis evidence no longer agrees'
      end
    end

    def tokens(value)
      value.to_s.unicode_normalize(:nfkd).gsub(/\p{M}/, '').downcase.scan(/[a-z0-9]+/)
    end
  end
end
