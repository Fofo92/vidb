module Tv
  class ProgrammeDisplayName
    def self.call(programme)
      name = title(programme)
      return if name.blank?

      episode = ProgrammeEpisodeLabel.call(programme)
      return name unless episode

      subtitle = subtitle(programme)
      label = "#{name} - #{episode}"
      subtitle.present? ? "#{label} - #{subtitle}" : label
    end

    def self.title(programme)
      localized(programme.titles)
    end

    def self.subtitle(programme)
      localized(programme.subtitles)
    end

    def self.localized(entries)
      entry = entries.find { |item| item["language"] == "fr" && item["value"].present? } ||
              entries.find { |item| item["value"].present? }
      entry&.fetch("value", nil)
    end
    private_class_method :localized
  end
end
