module Tv
  class ProgrammeEpisodeLabel
    def self.call(programme)
      entry = programme.episode_numbers.find { |number| number["system"] == "xmltv_ns" }
      match = entry&.fetch("value", nil)&.match(/\A(\d+)\.(\d+)\./)
      return unless match

      "Saison #{match[1].to_i + 1}, épisode #{match[2].to_i + 1}"
    end
  end
end
