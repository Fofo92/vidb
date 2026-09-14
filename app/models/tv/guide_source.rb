module Tv
  class GuideSource < ApplicationRecord
    has_many :guide_channels, dependent: :restrict_with_error

    validates :name, presence: true, uniqueness: true
    validates :display_name, :time_zone, presence: true
  end
end
