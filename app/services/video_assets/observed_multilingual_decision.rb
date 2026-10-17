# frozen_string_literal: true

module VideoAssets
  # French and another identified dialogue language establish VM without subtitles.
  class ObservedMultilingualDecision
    IDENTIFIED_LANGUAGES = %w[
      fra eng deu spa ita por rus ukr ara zho jpn kor nld pol tur heb hin swe dan nor fin ces hun ell ron
    ].freeze
    LANGUAGE_ALIASES = {
      'fr' => 'fra', 'fre' => 'fra', 'en' => 'eng', 'de' => 'deu', 'ger' => 'deu',
      'es' => 'spa', 'it' => 'ita', 'pt' => 'por', 'ru' => 'rus', 'uk' => 'ukr',
      'ar' => 'ara', 'zh' => 'zho', 'chi' => 'zho', 'ja' => 'jpn', 'ko' => 'kor',
      'nl' => 'nld', 'dut' => 'nld', 'pl' => 'pol', 'tr' => 'tur', 'he' => 'heb',
      'hi' => 'hin', 'sv' => 'swe', 'da' => 'dan', 'no' => 'nor', 'fi' => 'fin',
      'cs' => 'ces', 'cze' => 'ces', 'hu' => 'hun', 'el' => 'ell', 'gre' => 'ell',
      'ro' => 'ron', 'rum' => 'ron'
    }.freeze

    def initialize(streams, filename)
      @streams = streams
      @versions = (filename.fetch(:versions) + filename.fetch(:title_versions, [])).uniq
    end

    def call
      return unless @versions.empty? || [%w[VF], %w[VM]].include?(@versions)
      return if @streams.any? { |stream| stream['codec_type'] == 'subtitle' }
      return if audio.any? { |stream| auxiliary_audio?(stream) }

      return unless identified_multilingual_dialogue?

      ['candidate', 'VM',
       'Français et autre(s) langue(s) identifiée(s) observés, sans sous-titres ; ancien suffixe VF non déterminant.']
    end

    private

    def identified_multilingual_dialogue?
      languages = audio_languages.uniq
      languages.include?('fra') && languages.size > 1 && (languages - IDENTIFIED_LANGUAGES).empty?
    end

    def audio
      @streams.select { |stream| stream['codec_type'] == 'audio' }
    end

    def audio_languages
      audio.map do |stream|
        language = stream.fetch('tags', {})['language'].to_s.downcase
        LANGUAGE_ALIASES.fetch(language, language)
      end
    end

    def auxiliary_audio?(stream)
      %w[comment visual_impaired descriptions].any? do |name|
        stream.fetch('disposition', {}).fetch(name, 0).to_i.positive?
      end
    end
  end
end
