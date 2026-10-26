module EncoderProjects
  class WikipediaEpisodeLookup
    def initialize(wikipedia:, parser:)
      @wikipedia = wikipedia
      @parser = parser
    end

    def call(name, season, episode)
      main = page(name)
      expected = WikipediaSeasonTitle.call(name.sub(/\s*\(.*\)\z/, ''), season)
      dedicated = page(expected)
      raise ArgumentError, 'Pages Wikipédia indisponibles' unless main || dedicated

      proposal = @parser.call(dedicated, episode) if dedicated
      proposal ||= WikipediaSeasonEpisode.new.call(main, season, episode) if main
      return unless proposal

      [proposal, @parser.references(main || dedicated)]
    end

    private

    def page(title)
      result = @wikipedia.page(title)
      result if result.fetch('title').parameterize == title.parameterize
    rescue ArgumentError, KeyError, JSON::ParserError, CatalogEnrichment::TmdbClient::Error,
           IOError, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError
      nil
    end
  end
end
