# frozen_string_literal: true

module CatalogEnrichment
  # Explicit part markers are evidence; numbering alone is insufficient.
  class BroadcastPartName
    PATTERN = /
      \AS(?<season>\d+)\s*E(?<episode>\d+)\s*-\s*
      (?<title>.+),\s*partie\s+(?<part>[12])\s+
      \((?<original>.+)\)\z
    /ix

    def self.call(entry)
      stem = entry.fetch(:stem).sub(VideoAssets::TitleMatcher::LANGUAGE_SUFFIX, '').strip
      match = PATTERN.match(stem)
      return nil unless match

      { season: match[:season].to_i, local_number: match[:episode].to_i,
        part: match[:part].to_i, title: match[:title].strip, original: match[:original].strip,
        path: entry.fetch(:path), size: entry[:size], modified_at: entry[:modified_at] }
    end

    def self.normalize(title)
      title.to_s.unicode_normalize(:nfkc).downcase.tr('’', "'").gsub(/\s+/, ' ').strip
    end
  end
end
