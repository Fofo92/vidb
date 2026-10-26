module EncoderProjects
  class CatalogueCompletionProposal
    def self.call(proposals)
      proposals.map do |proposal|
        next proposal if proposal['catalogue_completion']

        matches = proposals.select do |item|
          item['catalogue_completion'] && EpisodeTitles.concordant?(proposal, item)
        end
        identities = matches.map { |item| item['catalogue_completion'] }.uniq
        next proposal unless identities.one?

        proposal.merge('catalogue_completion' => identities.sole)
      end
    end
  end
end
