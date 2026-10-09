# frozen_string_literal: true

module VideoAssets
  # A scoped confirmation may qualify legacy French audio, never a conflicting project.
  class ConfirmedSeriesLanguageDecision
    def self.call(proposal, asset)
      return proposal if proposal[:status] == 'already_qualified'
      return proposal unless proposal.dig(:encoder_evidence, :status) == 'absent'
      return proposal if proposal[:status] == 'candidate'
      return proposal if explicit_original?(proposal)

      reader = FilenameLanguageEvidence.new(asset.last_known_path, asset.technical_details.fetch('streams'))
      return proposal unless reader.compatible?('VF')

      proposal.merge(status: 'candidate', suggested_version: 'VF', basis: 'pascal_confirmation',
                     reason: 'Pascal confirme VF pour Blanca hors projets JSON ; pistes finales compatibles.')
    end

    def self.explicit_original?(proposal)
      versions = proposal.dig(:filename_evidence, :versions) || []
      versions.intersect?(%w[VO VOST VM VMST]) || versions.many?
    end
    private_class_method :explicit_original?
  end
end
