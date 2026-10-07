# frozen_string_literal: true

module VideoAssets
  class EncoderLanguageProposal
    def initialize(streams, evidence)
      @streams = streams
      @evidence = evidence
    end

    def call
      return unless @evidence[:status] == 'matched'

      languages = audio_languages
      return unless languages.present? && (languages - %w[fra fre fr qaa]).empty?
      return unless roles_match?(languages)

      original = languages.include?('qaa')
      french = languages.intersect?(%w[fra fre fr])
      return 'VF' unless original

      version = french ? 'VM' : 'VO'
      french_subtitles? ? "#{version}ST" : version
    end

    private

    def audio_languages
      @streams.select { |stream| stream['codec_type'] == 'audio' }.map do |stream|
        stream.fetch('tags', {})['language'].to_s.downcase
      end
    end

    def roles_match?(languages)
      return false if languages.include?('qaa') && !@evidence[:original_role_complete]
      return false if languages.intersect?(%w[fra fre fr]) && !@evidence[:french_role_complete]

      true
    end

    def french_subtitles?
      @streams.any? do |stream|
        disposition = stream.fetch('disposition', {})
        stream['codec_type'] == 'subtitle' &&
          %w[fra fre fr].include?(stream.fetch('tags', {})['language'].to_s.downcase) &&
          disposition['hearing_impaired'].to_i.zero? && disposition['forced'].to_i.zero?
      end
    end
  end
end
