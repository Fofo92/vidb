# frozen_string_literal: true

module VideoAssets
  class FilenameLanguageEvidence
    def initialize(path, streams)
      @path = path
      @streams = streams
    end

    def call
      stem = File.basename(@path, File.extname(@path))
      matches = stem.scan(/(?:\A|[ _.-])(VMST|VOST|VF|VO|VM)(?=\z|[ _.-])/i).flatten.map(&:upcase).uniq
      { versions: matches, version: matches.one? ? matches.first : nil }
    end

    def compatible?(version)
      audio = @streams.select { |stream| stream['codec_type'] == 'audio' }
      return false if audio.empty?

      languages = audio.map { |stream| stream.fetch('tags', {})['language'].to_s.downcase }
      return french_only?(languages) if version == 'VF'

      original_compatible?(version, languages)
    end

    private

    def original_compatible?(version, languages)
      return false unless %w[VO VOST].include?(version) && languages.one?
      return false if %w[fra fre fr].include?(languages.first)

      version == 'VO' || french_subtitles?
    end

    def french_only?(languages)
      languages.all? { |value| %w[fra fre fr].include?(value) } ||
        (languages.one? && ['', 'und'].include?(languages.first))
    end

    def french_subtitles?
      @streams.any? do |stream|
        stream['codec_type'] == 'subtitle' &&
          %w[fra fre fr].include?(stream.fetch('tags', {})['language'].to_s.downcase)
      end
    end
  end
end
