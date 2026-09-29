module Tv
  class ProgrammeEpisodeKey
    def self.call(programme)
      title = ProgrammeDisplayName.title(programme)&.squish&.downcase
      entry = programme.episode_numbers.find { |number| number["system"] == "xmltv_ns" }
      episode = entry&.fetch("value", nil)&.match(/\A(\d+)\.(\d+)\./)
      return if title.blank? || !episode

      [title, episode[1].to_i, episode[2].to_i]
    end
  end
end
