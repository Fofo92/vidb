# frozen_string_literal: true

class CatalogueEpisodeLink < ApplicationRecord
  belongs_to :record

  validates :provider, inclusion: { in: ['tmdb'] }
  validates :external_episode_id, uniqueness: { scope: :provider }
  validates :record_id, uniqueness: { scope: :provider }
  validates :external_series_id, :external_episode_id, :local_season_number, :local_episode_number,
            :external_season_number, :external_episode_number,
            numericality: { only_integer: true, greater_than: 0 }
end
