module EncoderProjects
  class EpisodeEditionTitles
    SUFFIX = /(?:\s*\((\d+)\)|\s*[-–—:]?\s+(?:part(?:ie)?|del)\s*(\d+))\s*\z/i

    def self.base(title)
      title.to_s.strip.sub(SUFFIX, '').strip
    end

    def self.part(title)
      match = SUFFIX.match(title.to_s)
      (match[1] || match[2]).to_i if match
    end

    def self.keys(titles)
      titles.compact_blank.flat_map do |title|
        [title, title.sub(/\s*\([^()]+\)\s*\z/, ''), *title.scan(/\(([^()]+)\)/).flatten].map do |value|
          base(value).gsub('&', ' et ').parameterize.gsub(/-(?:et|and|och)-/, '-')
        end
      end.reject(&:blank?).uniq
    end
  end
end
