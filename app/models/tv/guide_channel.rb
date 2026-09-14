module Tv
  class GuideChannel < ApplicationRecord
    belongs_to :guide_source
    belongs_to :channel, optional: true

    validates :external_id,
              presence: true,
              uniqueness: { scope: :guide_source_id }
  end
end
