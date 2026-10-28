module EncoderProjects
  class CatalogueCompletionProposal
    SHARED_FIELDS = %w[catalogue_completion edition_mapping external_parts numbering_source
                       reference_runtime_minutes].freeze

    def self.call(proposals)
      proposals.map do |proposal|
        next proposal if proposal['catalogue_completion']

        matches = proposals.select do |item|
          item['catalogue_completion'] && EpisodeTitles.concordant?(proposal, item)
        end
        identities = matches.map { |item| item['catalogue_completion'] }.uniq
        next proposal unless identities.one?

        shared = matches.first.slice(*SHARED_FIELDS)
        proposal.merge(shared)
      end
    end
  end
end
