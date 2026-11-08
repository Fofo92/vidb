# frozen_string_literal: true

class CatalogueEpisodeLink < ApplicationRecord
  belongs_to :record
  validate :whole_episode_without_local_partitions

  validates :provider, inclusion: { in: ['tmdb'] }
  validates :external_episode_id, uniqueness: { scope: :provider }
  validates :record_id, uniqueness: { scope: :provider }
  validates :external_series_id, :external_episode_id, :local_episode_number, :external_episode_number,
            numericality: { only_integer: true, greater_than: 0 }
  validates :local_season_number, :external_season_number,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  private

  def whole_episode_without_local_partitions
    ids = [external_episode_id, *Array(evidence['external_parts']).pluck('episode_id')]
    conflict = CatalogueEpisodePartition.where(record_id: record_id).exists? ||
               CatalogueEpisodePartition.where(external_episode_id: ids).exists?
    errors.add(:base, 'Cet épisode TMDB est représenté par des parties locales.') if conflict
  end
end
