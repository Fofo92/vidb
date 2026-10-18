require 'uri'

module ReconciliationWorkbench
  module EpisodeSourcePolicy
    VERSION = 'wikipedia_fr_first_v1'.freeze

    def self.preferred(references)
      return [] if references.empty?

      ranked = references.group_by { |reference| priority(reference.fetch('url')) }
      ranked.fetch(ranked.keys.min)
    end

    def self.priority(url)
      SeriesEvidence.source!(url)
      host = URI.parse(url).host.downcase
      return 0 if %w[fr.wikipedia.org fr.m.wikipedia.org].include?(host)
      return 1 if host.match?(/\A[a-z][a-z0-9-]*(?:\.m)?\.wikipedia\.org\z/)

      2
    end

    def self.french_title(references, title)
      canonical = references.find do |reference|
        priority(reference.fetch('url')).zero? &&
          SeriesTitles.key(reference.fetch('name')) == SeriesTitles.key(title)
      end
      canonical ? canonical.fetch('name') : title
    end
  end
end
