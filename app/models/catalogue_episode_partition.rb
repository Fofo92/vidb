class CatalogueEpisodePartition < ApplicationRecord
  belongs_to :record

  validates :record_id, uniqueness: true
  validates :external_episode_id, uniqueness: { scope: :part_number }
  validates :external_series_id, :external_episode_id, :external_episode_number, :part_number,
            numericality: { only_integer: true, greater_than: 0 }
  validates :part_count, numericality: { only_integer: true, greater_than: 1 }
  validates :part_number, numericality: { less_than_or_equal_to: :part_count }
  validates :external_season_number, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
