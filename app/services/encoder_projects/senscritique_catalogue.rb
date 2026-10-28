module EncoderProjects
  class SenscritiqueCatalogue
    attr_reader :warnings

    def initialize(client: SenscritiqueClient.new, parser: SenscritiqueFilm.new)
      @client = client
      @parser = parser
      @warnings = []
    end

    def call(query)
      @warnings = []
      url = @client.film_url(query)
      return collect([url]) if url
      return [] if query.to_s.match?(%r{\Ahttps?://}i)

      matching_proposals(@client.search(query), query)
    rescue SenscritiqueClient::Error => e
      @warnings << e.message
      []
    end

    private

    def matching_proposals(urls, query)
      proposals = collect(urls)
      matches = proposals.select { |proposal| matching_title?(proposal, query) }
      @warnings << 'SensCritique : suggestions sans concordance de titre écartées.' if matches.size < proposals.size
      matches
    end

    def matching_title?(proposal, query)
      title = query.to_s.strip
      dated = title.match(/\A(.+?)\s+\(((?:19|20)\d{2})\)\z/)
      return false if dated && proposal['year'] != dated[2].to_i

      expected = SynopsisPreference.normalized_titles([dated ? dated[1] : title])
      actual = SynopsisPreference.normalized_titles(proposal.values_at('french_title', 'original_title'))
      expected.intersect?(actual)
    end

    def collect(urls)
      urls.filter_map do |url|
        proposal = @parser.call(@client.page(url), url: url)
        @warnings << 'SensCritique : fiche non exploitable automatiquement ; aucun champ inventé.' unless proposal
        proposal
      rescue SenscritiqueClient::Error => e
        @warnings << e.message
        nil
      end
    end
  end
end
