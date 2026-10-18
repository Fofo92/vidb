module ReconciliationWorkbench
  module SeriesTitles
    def self.key(value)
      value.to_s.unicode_normalize(:nfkd).downcase.gsub(/[^\p{Alnum}]/, '')
    end

    def self.parts(title)
      title = title.to_s.sub(/(?:_vf|\s*\((?:VF|VO|VOST|VM|VMST)\))+\z/i, '').strip
      match = title.match(/\A(.+?)\s+\(([^()]*)\)\z/)
      match ? [title, match[1], match[2]] : [title]
    end

    def self.keys(title)
      parts(title).map { |part| key(part) }.reject(&:empty?).uniq
    end

    def self.index
      result = Hash.new { |hash, key| hash[key] = [] }
      Record.pluck(:id, :french_title, :original_title).each do |id, french, original|
        [french, original].filter_map { |title| key(title).presence }.uniq.each { |title| result[title] << id }
      end
      result
    end

    def self.candidates(index, title)
      keys(title).flat_map { |key| index[key] }.uniq.sort
    end
  end
end
