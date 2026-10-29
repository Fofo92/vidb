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
      captures = @captures.call(programmes.reject { |programme| library[programme.id]&.kind == 'available' })
      library.merge(captures) { |_, copy, source| source_with_copy(source, copy) }
    end

    private

    def source_with_copy(source, copy)
      EpisodeAcquisition.new(kind: source.kind, label: source.label,
                             description: "#{source.description} #{copy.label} : #{copy.description}",
                             record_id: copy.record_id, paths: source.paths)
    end
  end
end
