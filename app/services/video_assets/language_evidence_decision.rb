# frozen_string_literal: true

module VideoAssets
  class LanguageEvidenceDecision
    def initialize(filename_reader, filename, encoder_version)
      @reader = filename_reader
      @filename = filename
      @encoder_version = encoder_version
    end

    def call
      return review('Plusieurs versions contradictoires figurent dans le nom.') if @filename[:versions].size > 1

      version = @filename[:version]
      return encoder_decision(version) if @encoder_version
      return unless version
      return review('Le nom et les pistes observées ne permettent pas de conclure.') unless @reader.compatible?(version)

      ['candidate', version, 'Version indiquée dans le nom et compatible avec les pistes observées.']
    end

    private

    def encoder_decision(filename_version)
      if filename_version && filename_version != @encoder_version
        return review('Contradiction entre le nom et la politique video_encoder appliquée aux pistes finales.')
      end

      ['candidate', @encoder_version, 'Rôles des pistes finales interprétés selon la politique video_encoder.']
    end

    def review(reason)
      ['needs_review', nil, reason]
    end
  end
end
