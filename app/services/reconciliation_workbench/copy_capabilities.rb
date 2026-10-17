module ReconciliationWorkbench
  class CopyCapabilities
    LANGUAGES = { 'fr' => 'fra', 'fre' => 'fra', 'en' => 'eng', 'de' => 'deu', 'ger' => 'deu',
                  'es' => 'spa', 'it' => 'ita', 'ja' => 'jpn' }.freeze

    def initialize(sample)
      @sample = sample
      @streams = sample.fetch('measurement').fetch('technical_details').fetch('streams')
    end

    def call
      { 'audio' => tracks('audio'), 'subtitles' => tracks('subtitle'), 'language_assumptions' => assumptions,
        'video' => video, 'seconds' => @sample.fetch('measurement').fetch('measured_duration_seconds'),
        'bytes' => @sample.fetch('measurement').fetch('byte_size'),
        'modified_at' => @sample.fetch('modified_at'), 'encoder_verified' => @sample.fetch('encoder_verified') }
    end

    private

    def tracks(type)
      selected = @streams.select { |stream| stream['codec_type'] == type }
      selected.map { |stream| track(stream, type) }.uniq.sort
    end

    def track(stream, type)
      language = track_language(stream, type)
      role = stream.fetch('disposition', {}).slice('forced', 'hearing_impaired', 'visual_impaired', 'comment')
      role = role.select { |_key, value| value.to_i == 1 }.keys.sort
      channels = type == 'audio' ? Integer(stream.fetch('channels')) : 0
      raise ArgumentError, 'Canaux audio inconnus' if type == 'audio' && channels < 1

      [LANGUAGES.fetch(language, language), role, channels]
    end

    def track_language(stream, type)
      language = stream.fetch('tags', {}).fetch('language', '').downcase.strip
      language = 'fra' if type == 'audio' && single_und_audio?(stream)
      if language.empty? || %w[und mul zxx].include?(language) || /\Aq[a-t][a-z]\z/.match?(language)
        raise ArgumentError, 'Une langue de piste est inconnue : comparaison à examiner'
      end

      language
    end

    def single_und_audio?(stream)
      stream.fetch('tags', {}).fetch('language', '').strip.downcase == 'und' &&
        @streams.one? { |item| item['codec_type'] == 'audio' }
    end

    def assumptions
      return [] unless @streams.any? { |stream| stream['codec_type'] == 'audio' && single_und_audio?(stream) }

      ['Piste audio unique marquée und : français retenu selon la règle de la vidéothèque.']
    end

    def video
      videos = @streams.select { |stream| stream['codec_type'] == 'video' }
      raise ArgumentError, 'Une seule piste vidéo principale est requise' unless videos.one?

      width, height = videos.first.values_at('width', 'height').map(&:to_i)
      raise ArgumentError, 'Dimensions vidéo inconnues' unless width.positive? && height.positive?

      [width, height]
    end
  end
end
