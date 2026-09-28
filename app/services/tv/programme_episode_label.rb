module Tv
  class ProgrammeEpisodeLabel
    def self.call(programme)
      season, episode = numbers(programme)
      return unless season

      format("S%<season>02d E%<episode>02d", season:, episode:)
    end

    def self.legacy(programme)
      season, episode = numbers(programme)
      return unless season

      "Saison #{season}, épisode #{episode}"
    end

    def self.numbers(programme)
      entry = programme.episode_numbers.find { |number| number["system"] == "xmltv_ns" }
      match = entry&.fetch("value", nil)&.match(/\A(\d+)\.(\d+)\./)
      return unless match

      [match[1].to_i + 1, match[2].to_i + 1]
    end
    private_class_method :numbers
  end
end
