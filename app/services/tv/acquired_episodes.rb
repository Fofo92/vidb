module Tv
  class AcquiredEpisodes
    def initialize(library: LibraryEpisodeAcquisitions.new, captures: CaptureEpisodeAcquisitions.new)
      @library = library
      @captures = captures
    end

    def call(programmes)
      programmes = programmes.select { |programme| AcquiredEpisodeIdentity.key(programme) }
      return {} if programmes.empty?

      library = @library.call(programmes)
      captures = @captures.call(programmes.reject { |programme| library.key?(programme.id) })
      captures.merge(library)
    end
  end
end
