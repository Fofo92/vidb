# frozen_string_literal: true

require 'date'

module CatalogEnrichment
  # A matching title alone never establishes a film identity.
  class FilmIdentityComparison
    STOP_WORDS = %w[avec dans pour plus une des les est sur qui que son ses aux par pas cette leur elle lui
                    mais entre tout tous sans comme fait deux autre lors sont ils the and for with from that
                    this].freeze

    def call(local:, results:)
      candidates = results.map { |film| compare(local, film) }
      accepted = candidates.select { |candidate| candidate[:supported] }
      { status: accepted.one? ? 'candidate' : 'needs_review',
        tmdb_id: accepted.one? ? accepted.first[:tmdb_id] : nil, comparisons: candidates,
        reason: comparison_reason(accepted) }
    end

    private

    def comparison_reason(accepted)
      return 'Titre, synopsis et proximité chronologique concordants.' if accepted.one?

      'Identité absente, insuffisamment étayée ou multiple.'
    end

    def compare(local, film)
      evidence = comparison_evidence(local, film)
      supported = film['id'].is_a?(Integer) && film['id'].positive? &&
                  evidence.values_at(:title_matches, :year_compatible).all? &&
                  evidence[:shared_synopsis_terms] >= 5 && evidence[:synopsis_overlap] >= 0.5
      overview = film['overview'] if evidence.values_at(:title_matches, :year_compatible).all?
      film.slice('title', 'original_title', 'release_date').symbolize_keys
          .merge(evidence, tmdb_id: film['id'], supported: supported, external_overview: overview)
    end

    def comparison_evidence(local, film)
      own = [local['french_title'], local['original_title']].filter_map { |title| normalized(title).presence }
      titles = [film['title'], film['original_title']].map { |title| normalized(title) }
      overlap = synopsis_overlap(local['abstract'], film['overview'])
      year = release_year(film['release_date'])
      { title_matches: own.intersect?(titles), shared_synopsis_terms: overlap[:shared],
        synopsis_overlap: overlap[:ratio], year_compatible: compatible_year?(local['year'], year) }
    end

    def compatible_year?(local, external)
      local.nil? || (!external.nil? && (local - external).abs <= 2)
    end

    def normalized(text)
      text.to_s.unicode_normalize(:nfkd).gsub(/\p{Mn}/, '').downcase.gsub(/[^\p{Alnum}]+/, ' ').strip
    end

    def synopsis_overlap(first, second)
      sets = [first, second].map { |text| meaningful_words(text) }
      shared = (sets.first & sets.last).size
      minimum = sets.map(&:size).min
      { shared: shared, ratio: minimum.zero? ? 0.0 : shared.fdiv(minimum).round(4) }
    end

    def meaningful_words(text)
      normalized(text).split.reject { |word| word.size < 3 || STOP_WORDS.include?(word) }.to_set
    end

    def release_year(value)
      return unless value.is_a?(String) && value.match?(/\A\d{4}-\d{2}-\d{2}\z/)

      Date.iso8601(value).year
    rescue Date::Error
      nil
    end
  end
end
