# frozen_string_literal: true

module EncoderProjects
  # The source hint proposes a version; the reviewed form remains authoritative.
  class PlannedLanguage
    def self.call(proposal:, project:, submitted: {}, series: nil)
      selected = submitted['language_version'].presence || existing_version(proposal)
      selected || suggested_version(proposal, project, series)
    end

    def self.existing_version(proposal)
      return unless proposal['existing_record_id']

      version = proposal['language_version'].presence
      version unless version == 'IND'
    end
    private_class_method :existing_version

    def self.suggested_version(proposal, project, series)
      hint = project['language_hint'].presence
      return proposal['language_version'].presence || 'IND' if hint.blank? || hint == 'IND'
      return hint unless %w[VM VMST VO VOST].include?(hint)

      french_original?(original_language(proposal, series)) ? 'VF' : hint
    end
    private_class_method :suggested_version

    def self.original_language(proposal, series)
      evidence = proposal.dig('series_candidate', 'original_language_evidence')
      return evidence if evidence

      OriginalLanguage.call(series) if series
    end
    private_class_method :original_language

    def self.french_original?(evidence)
      evidence.is_a?(Hash) && evidence['provider'] == 'tmdb' &&
        evidence['status'] == 'french' && evidence['language'] == 'fr'
    end
    private_class_method :french_original?
  end
end
