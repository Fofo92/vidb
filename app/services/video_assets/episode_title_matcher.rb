# frozen_string_literal: true

module VideoAssets
  # Separates exact title evidence, generic titles and parenthesized variants.
  class EpisodeTitleMatcher
    LANGUAGE_SUFFIX = TitleMatcher::LANGUAGE_SUFFIX
    ORIGINAL_SUFFIX = /\s+\(([^()]*)\)\z/

    def self.call(record, title, episode_number)
      matcher = TitleMatcher.new([record])
      generic = /\A[ÉE]pisode\s+(\d+)\z/i.match(record.french_title.to_s)
      return evidence('episode_candidate', 'title_not_comparable', title) if
        title.empty? || (generic && generic[1].to_i == episode_number)
      return evidence('episode_candidate', 'title_match', title) if matcher.match(title)[:candidates].any?

      variant_evidence(matcher, title)
    end

    def self.variant_evidence(matcher, title)
      stripped = title.sub(LANGUAGE_SUFFIX, '').strip
      suffix = ORIGINAL_SUFFIX.match(stripped)
      french_title = stripped.sub(ORIGINAL_SUFFIX, '').strip
      if suffix && matcher.match(french_title)[:candidates].any?
        return evidence('episode_title_variant', 'parenthesized_title_difference', title)
      end

      evidence('episode_title_conflict', 'title_difference', title)
    end

    def self.evidence(status, reason, title)
      { status: status, title_evidence: reason, observed_title: title }
    end
    private_class_method :variant_evidence, :evidence
  end
end
