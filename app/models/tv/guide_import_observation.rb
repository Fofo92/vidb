module Tv
  class GuideImportObservation < ApplicationRecord
    belongs_to :guide_import
    belongs_to :broadcast_observation

    validates :broadcast_observation,
              uniqueness: { scope: :guide_import_id }
  end
end
