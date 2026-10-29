module EncoderProjects
  class ReviewedEpisodeReference
    def self.validate!(candidate, parameters)
      return unless candidate&.key?('tmdb_episode_reference')
      return if parameters['confirm_tmdb_episode_mapping'] == '1'

      raise ArgumentError, 'Confirme la correspondance entre l’épisode local et l’épisode TMDB.'
    end

    def call(record, candidate)
      reference = candidate&.fetch('tmdb_episode_reference', nil)
      return unless reference

      verify_series!(record, reference.fetch('series_id'))
      attributes = attributes_for(record, reference)
      link = CatalogueEpisodeLink.find_or_initialize_by(provider: 'tmdb', record_id: record.id)
      verify_existing!(link, attributes)
      evidence = (link.evidence || {}).merge('explicit_episode_mapping' => true,
                                             'reviewed_source' => candidate.fetch('source'))
      link.update!(attributes.merge(evidence: evidence))
    end

    private

    def verify_series!(record, id)
      ids = CatalogueEpisodeLink.where(provider: 'tmdb', record_id: record.parent.parent.subtree.select(:id))
                                .distinct.pluck(:external_series_id)
      return if ids.all? { |existing| existing == id }

      raise ArgumentError, 'Cette série possède une autre identité TMDB : vérifie ses liens catalogue.'
    end

    def attributes_for(record, reference)
      { external_series_id: reference.fetch('series_id'), external_episode_id: reference.fetch('episode_id'),
        external_season_number: reference.fetch('season'), external_episode_number: reference.fetch('episode'),
        local_season_number: record.parent.rank, local_episode_number: record.rank }
    end

    def verify_existing!(link, attributes)
      return if link.new_record? || attributes.all? { |key, value| link.public_send(key) == value }

      raise ArgumentError, 'Cet épisode possède une autre correspondance TMDB : vérifie ses liens catalogue.'
    end
  end
end
