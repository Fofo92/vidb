# frozen_string_literal: true

module VideoAssets
  # Shared catalogue convention for legacy copies without an interpretable project.
  class SingleAudioLanguageDecision
    def initialize(streams, filename, title)
      @audio = streams.select { |stream| stream['codec_type'] == 'audio' }
      title_versions = FilenameLanguageEvidence.new(title.to_s, streams).call.fetch(:versions)
      @versions = (filename.fetch(:versions) + title_versions).uniq
    end

    def call
      return unless @audio.one?
      return review if @versions.many? || @versions.intersect?(%w[VM VMST])

      original = (@versions & %w[VO VOST]).first
      return original_decision(original) if original

      ['candidate', 'VF', 'Une seule piste audio, sans mention VO/VOST : convention automatique du catalogue.']
    end

    private

    def original_decision(version)
      language = @audio.first.fetch('tags', {})['language'].to_s.downcase
      return review if %w[fra fre fr].include?(language)

      ['candidate', version, 'Une seule piste audio et mention explicite VO/VOST dans le nom ou le titre.']
    end

    def review
      ['needs_review', nil, 'Les mentions de version et les pistes audio sont contradictoires.']
    end
  end
end
