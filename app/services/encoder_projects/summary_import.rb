module EncoderProjects
  class SummaryImport
    def initialize(candidate:, parameters:)
      @candidate = candidate
      @parameters = parameters
    end

    def call(record, text)
      validate_existing!(record) if record.abstract.present?
      raise ArgumentError, 'Résumé limité à 12 000 caractères' if text.length > 12_000

      if edited?
        record.update!(abstract: text)
      else
        record.save_external_abstract!(text, source: @candidate['abstract_source'] || @candidate.fetch('source', {}))
      end
    end

    private

    def edited?
      @parameters['abstract'].present? && @parameters['abstract'] != @candidate['abstract']
    end

    def validate_existing!(record)
      replacement = @candidate['replace_external_abstract'] && !record.abstract_protected?
      raise ArgumentError, 'Résumé protégé : recharge le formulaire pour le corriger.' unless edited? || replacement

      previous = @candidate.fetch('previous_abstract', @candidate['abstract'])
      return if record.abstract == previous

      raise ArgumentError,
            'Résumé modifié depuis la proposition : recharge le formulaire.'
    end
  end
end
