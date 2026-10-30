module Tv
  class LibraryAcquisitionCandidates
    def initialize(episodes: LibraryEpisodeCandidates.new, works: LibraryWorkCandidates.new)
      @episodes = episodes
      @works = works
    end

    def call(programmes)
      @episodes.call(programmes).merge(@works.call(programmes))
    end
  end
end
