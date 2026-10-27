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

      collect(@client.search(query))
    rescue SenscritiqueClient::Error => e
      @warnings << e.message
      []
    end

    private

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
