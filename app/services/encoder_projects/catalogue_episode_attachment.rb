module EncoderProjects
  class CatalogueEpisodeAttachment
    def initialize(series_id:, metadata:)
      @series_id = series_id
      @metadata = metadata
    end

    def identity?(record, row)
      CatalogueEpisodeLink.where(record: record, provider: 'tmdb', **values(row)).exists?
    end

    def call(record, row)
      check_other_owners!(record, row)
      link = CatalogueEpisodeLink.find_or_initialize_by(record: record, provider: 'tmdb')
      validate_identity!(link, row)
      check_existing_parts!(link, row) if link.persisted?
      evidence = evidence_for(row)
      link.assign_attributes(values(row).merge(evidence: (link.evidence || {}).merge(evidence)))
      link.save! if link.changed?
    end

    private

    def validate_identity!(link, row)
      return unless link.persisted? && values(row).any? { |key, value| link[key] != value }

      raise ArgumentError, 'Identité externe existante différente'
    end

    def evidence_for(row)
      evidence = @metadata.source(row).merge('reference_runtime_minutes' => row['reference_runtime_minutes'])
      evidence.merge(row.slice('external_parts', 'numbering_source')).tap do |result|
        result['local_title'] = row['title_fr'] if row['numbering_source']
      end
    end

    def values(row)
      { external_series_id: @series_id, external_episode_id: row.fetch('tmdb_episode_id'),
        local_season_number: row.fetch('season_number'), external_season_number: row.fetch('season_number'),
        local_episode_number: row.fetch('episode_number'),
        external_episode_number: row.fetch('external_episode_number', row.fetch('episode_number')) }
    end

    def ids(row)
      row.fetch('external_parts', []).pluck('episode_id').presence || [row.fetch('tmdb_episode_id')]
    end

    def check_existing_parts!(link, row)
      previous = Array(link.evidence['external_parts']).pluck('episode_id')
      return if previous.empty? || previous == ids(row)

      raise ArgumentError, 'Le découpage externe existant diffère : vérifie la correspondance avant modification.'
    end

    def check_other_owners!(record, row)
      links = CatalogueEpisodeLink.where(provider: 'tmdb', external_series_id: @series_id).where.not(record: record)
      conflict = links.any? do |link|
        owned = [link.external_episode_id, *Array(link.evidence['external_parts']).pluck('episode_id')]
        owned.intersect?(ids(row))
      end
      raise ArgumentError, 'Une partie du catalogue est déjà associée à une autre fiche.' if conflict
    end
  end
end
