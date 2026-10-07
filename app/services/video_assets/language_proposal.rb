# frozen_string_literal: true

module VideoAssets
  class LanguageProposal
    def initialize(asset)
      @asset = asset
    end

    def call
      return result('already_qualified', nil, 'Version déjà renseignée pour cette copie.') if @asset.language_version_id

      audio = streams.select { |stream| stream['codec_type'] == 'audio' }
      languages = audio.map { |stream| language(stream) }
      proposal(languages)
    end

    private

    def streams
      @asset.technical_details.fetch('streams', [])
    end

    def language(stream)
      value = stream.fetch('tags', {})['language'].to_s.downcase
      { 'fr' => 'fra', 'fre' => 'fra', 'en' => 'eng' }.fetch(value, value)
    end

    def proposal(languages)
      return result('needs_review', nil, 'Aucune piste audio relevée.') if languages.empty?
      if languages.intersect?(['', 'und', 'mul', 'zxx', 'qaa'])
        return result('needs_review', nil, 'Au moins une langue audio reste indéterminée.')
      end

      if languages.uniq == ['fra']
        return result('candidate', 'VF', 'Toutes les pistes audio sont déclarées en français ; écoute à confirmer.')
      end

      multilingual_proposal(languages)
    end

    def multilingual_proposal(languages)
      if languages.include?('fra') && languages.uniq.size > 1
        return result('candidate', 'VM', 'Français et autre langue déclarés ; nature des pistes à confirmer.')
      end

      result('needs_review', nil,
             'La langue originale et les sous-titres doivent être vérifiés pour qualifier VO/VOST.')
    end

    def result(status, suggested_version, reason)
      {
        video_asset_id: @asset.id, record_id: @asset.record_id,
        title: @asset.record.complete_title, path: @asset.last_known_path,
        status: status, current_version: @asset.language_version&.short_name,
        suggested_version: suggested_version, reason: reason,
        observed_at: @asset.technical_details['observed_at'],
        declared_audio_languages: declared_audio_languages
      }
    end

    def declared_audio_languages
      streams.select { |stream| stream['codec_type'] == 'audio' }.map do |stream|
        stream.fetch('tags', {})['language']
      end
    end
  end
end
