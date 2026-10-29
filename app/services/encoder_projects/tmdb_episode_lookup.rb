module EncoderProjects
  class TmdbEpisodeLookup
    def initialize(client:, page:, links:, warnings:)
      @client = client
      @page = page
      @links = links
      @warnings = warnings
    end

    def call(id, series, numbers, reference: nil)
      reference ||= stored_reference(id, series, numbers)
      builder = builder_for(reference)
      proposal = reference ? builder.call(id, reference) : builder.call(id, series, numbers)
      return missing_episode(id, numbers) unless proposal

      proposal = yield(proposal, builder.series_data)
      return proposal if reference

      proposal.merge('catalogue_completion' => { 'tmdb_id' => id, 'record_id' => series.id })
    end

    private

    def missing_episode(id, numbers)
      @warnings << format('TMDB : aucun épisode correspondant à S%02d E%02d dans la série %s. ' \
                          'Si sa numérotation diffère, saisis l’URL exacte de l’épisode.',
                          numbers.season, numbers.episode, id)
      nil
    end

    def stored_reference(id, series, numbers)
      scope = @links.where(provider: 'tmdb', record_id: series.subtree.select(:id))
      return unless scope.respond_to?(:to_a)

      link = scope.to_a.find do |item|
        item.respond_to?(:evidence) && item.evidence['explicit_episode_mapping'] && item.external_series_id == id &&
          item.local_season_number == numbers.season && item.local_episode_number == numbers.episode
      end
      return unless link

      { 'season' => link.external_season_number, 'episode' => link.external_episode_number,
        'episode_id' => link.external_episode_id }
    end

    def builder_for(reference)
      return TmdbEpisodeUrlProposal.new(client: @client, warnings: @warnings) if reference

      TmdbEpisodeProposal.new(client: @client, wikipedia_page: @page, links: @links, warnings: @warnings)
    end
  end
end
