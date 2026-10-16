# frozen_string_literal: true

module VideoAssets
  # Final French and English audio without subtitles establish VM despite a legacy VF suffix.
  class ObservedMultilingualDecision
    def initialize(streams, filename)
      @streams = streams
      @versions = (filename.fetch(:versions) + filename.fetch(:title_versions, [])).uniq
    end

    def call
      return unless @versions.empty? || [%w[VF], %w[VM]].include?(@versions)
      return if @streams.any? { |stream| stream['codec_type'] == 'subtitle' }
      return unless audio_languages.uniq.sort == %w[eng fra]

      ['candidate', 'VM',
       'Pistes française et anglaise observées, sans sous-titres ; ancien suffixe VF non déterminant.']
    end

    private

    def audio_languages
      @streams.select { |stream| stream['codec_type'] == 'audio' }.map do |stream|
        language = stream.fetch('tags', {})['language'].to_s.downcase
        { 'fr' => 'fra', 'fre' => 'fra', 'en' => 'eng' }.fetch(language, language)
      end
    end
  end
end
