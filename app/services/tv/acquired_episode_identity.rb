module Tv
  class AcquiredEpisodeIdentity
    SEASON_SUFFIX = /\s*[-–—]\s*Saison\s+(\d+)\s*\z/i

    def self.key(programme)
      entry = programme.episode_numbers.find { |item| item['system'] == 'xmltv_ns' }
      numbers = entry&.fetch('value', nil)&.match(/\A(\d+)\.(\d+)\./)
      return unless numbers

      season = numbers[1].to_i + 1
      title = ProgrammeDisplayName.title(programme).to_s
      suffix = SEASON_SUFFIX.match(title)
      return if suffix && suffix[1].to_i != season

      name = normalize(title.sub(SEASON_SUFFIX, ''))
      [name, season, numbers[2].to_i + 1] if name.present?
    end

    def self.normalize(value)
      value.to_s.gsub('&', ' et ').parameterize
    end

    def self.titles(record)
      [record.french_title, record.original_title].filter_map do |title|
        normalize(title).presence
      end.uniq
    end

    def self.concordant?(programme, titles)
      subtitle = ProgrammeDisplayName.subtitle(programme)
      subtitle.blank? || titles.include?(normalize(subtitle))
    end
  end
end
