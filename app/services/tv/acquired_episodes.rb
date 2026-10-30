module Tv
  class AcquiredEpisodes
    def initialize(library: LibraryEpisodeAcquisitions.new, captures: CaptureEpisodeAcquisitions.new)
      @library = library
      @captures = captures
    end

    def call(programmes)
      programmes = programmes.select { |programme| ProgrammeDisplayName.title(programme).present? }
      return {} if programmes.empty?

      library = @library.call(programmes)
      captures = @captures.call(capture_programmes(programmes, library))
      library.merge(captures) { |_, copy, source| source_with_copy(source, copy) }
    end

    private

    def capture_programmes(programmes, library)
      programmes.reject { |programme| library[programme.id]&.kind == 'available' }
    end

    def source_with_copy(source, copy)
      EpisodeAcquisition.new(kind: source.kind, label: source.label,
                             description: "#{source.description} #{copy.label} : #{copy.description}",
                             record_id: copy.record_id, paths: source.paths)
    end
  end
end
