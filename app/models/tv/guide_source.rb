module Tv
  class GuideSource < ApplicationRecord
    validates :name, presence: true, uniqueness: true
    validates :display_name, :time_zone, presence: true
  end
end
