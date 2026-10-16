# frozen_string_literal: true

module VideoAssets
  class LanguageProposal
    def initialize(asset)
      @asset = asset
    end

    def call
      return result('already_qualified', nil, 'Version déjà renseignée pour cette copie.') if @asset.language_version_id

      decision = evidence_decision
      return result(*decision) if decision

      proposal(streams.select { |stream| stream['codec_type'] == 'audio' }.map { |stream| language(stream) })
    end

    private

    def evidence_decision
      reader = collect_evidence
      if @encoder_evidence[:status] == 'copy_not_stable'
        return ['needs_review', nil, 'Copie absente, récente ou modifiée depuis son observation.']
      end

      return silent_decision if @asset.record.language_version&.silent?

      return project_decision(reader) unless @encoder_evidence[:status] == 'absent'

      legacy_decision(reader)
    end

    def silent_decision
      @basis = 'declared_silent_work'
      unless silent_copy_available?
        return ['needs_review', nil, 'Copie muette absente, récente ou modifiée depuis son référencement.']
      end

      ['candidate', @asset.record.language_version.short_name,
       'Œuvre qualifiée Muet dans la fiche ; les pistes sonores ne constituent pas un dialogue.']
    end

    def silent_copy_available?
      path = @asset.last_known_path
      stat = File.lstat(path)
      stat.file? && File.realpath(path) == path && stat.size == @asset.byte_size &&
        stat.mtime <= Time.current - 24.hours
    rescue SystemCallError
      false
    end

    def legacy_decision(reader)
      @basis = 'single_audio_policy_v1'
      single = SingleAudioLanguageDecision.new(streams, @filename_evidence, @asset.record.complete_title).call
      return single if single

      observed_decision(reader)
    end

    def observed_decision(reader)
      @basis = 'observed_multilingual_policy_v1'
      decision = ObservedMultilingualDecision.new(streams, @filename_evidence).call
      return decision if decision

      @basis = 'language_proposal_v3'
      LanguageEvidenceDecision.new(reader, @filename_evidence, nil).call
    end

    def project_decision(reader)
      @basis = 'encoder_project_policy'
      version = EncoderLanguageProposal.new(streams, @encoder_evidence).call
      return LanguageEvidenceDecision.new(reader, @filename_evidence, version).call if version

      ['needs_review', nil, 'Le projet JSON voisin ne permet pas de qualifier cette copie sans ambiguïté.']
    end

    def collect_evidence
      reader = FilenameLanguageEvidence.new(@asset.last_known_path, streams)
      @filename_evidence = reader.call
      @filename_evidence[:title_versions] =
        FilenameLanguageEvidence.new(@asset.record.complete_title, streams).call[:versions]
      @encoder_evidence = EncoderLanguageEvidence.new(@asset).call
      reader
    end

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
        return result('candidate', 'VF',
                      'Pistes audio déclarées en français : qualification automatique.')
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
        declared_audio_languages: declared_audio_languages,
        filename_evidence: @filename_evidence, encoder_evidence: @encoder_evidence, basis: @basis
      }
    end

    def declared_audio_languages
      streams.select { |stream| stream['codec_type'] == 'audio' }.map do |stream|
        stream.fetch('tags', {})['language']
      end
    end
  end
end
