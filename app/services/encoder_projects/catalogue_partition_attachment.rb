module EncoderProjects
  class CataloguePartitionAttachment
    def initialize(series_id:, metadata:)
      @series_id = series_id
      @metadata = metadata
    end

    def call(record, row)
      values = attributes(row)
      verify_whole_links!(record, values)
      verify_other_parts!(record, values)
      link = CatalogueEpisodePartition.find_or_initialize_by(record: record)
      raise ArgumentError, 'La correspondance de partie existante est différente.' unless
        link.new_record? || values.all? { |key, value| link.public_send(key) == value }

      link.update!(values.merge(evidence: @metadata.source(row).merge(row.fetch('local_partition'))))
    end

    private

    def attributes(row)
      { external_series_id: @series_id, external_episode_id: row.fetch('tmdb_episode_id'),
        external_season_number: row.fetch('season_number'),
        external_episode_number: row.fetch('external_episode_number'),
        part_number: row.fetch('local_partition').fetch('part_number'),
        part_count: row.fetch('local_partition').fetch('part_count') }
    end

    def verify_whole_links!(record, values)
      links = CatalogueEpisodeLink.where(provider: 'tmdb')
      conflict = links.where(record: record).exists? || links.where(external_series_id: @series_id).any? do |link|
        ids = [link.external_episode_id, *Array(link.evidence['external_parts']).pluck('episode_id')]
        ids.include?(values.fetch(:external_episode_id))
      end
      raise ArgumentError, 'Une fiche représente déjà cet épisode TMDB entier : correspondance à examiner.' if conflict
    end

    def verify_other_parts!(record, values)
      others = CatalogueEpisodePartition.where(external_episode_id: values.fetch(:external_episode_id))
                                        .where.not(record: record).includes(:record)
      valid = others.all? do |link|
        link.external_series_id == @series_id && link.part_count == values.fetch(:part_count) &&
          link.record.parent_id == record.parent_id && link.part_number != values.fetch(:part_number)
      end
      raise ArgumentError, 'Cet épisode double est déjà représenté par un autre découpage.' unless valid
    end
  end
end
