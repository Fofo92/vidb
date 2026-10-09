# frozen_string_literal: true

module CatalogEnrichment
  # Filename decorations are evidence, not part of the external episode title.
  class EpisodeFilenameTitle
    PREFIX = /\AS(?<season>\d+)\s*E(?<episode>\d+)\s*[-–—]\s*(?<title>.+)\z/i
    LANGUAGE = /_(?<marker>VF|VO|VOSTFR|VOST|VMST|VM)\z/i

    def self.parse(stem)
      match = PREFIX.match(stem)
      return unless match

      raw = match[:title]
      marker = LANGUAGE.match(raw)
      title = raw.sub(LANGUAGE, '').strip
      { season: match[:season].to_i, episode: match[:episode].to_i, title: title, raw_title: raw,
        language_marker: marker&.[](:marker)&.upcase,
        ambiguous_part_suffix: /\s+\(\d+\)\z/.match?(title) }
    end

    def self.title_variants(title)
      split = /\A(.+?)\s+\((.+)\)\z/.match(title)
      split ? [title, *split.captures] : [title]
    end
  end
end
