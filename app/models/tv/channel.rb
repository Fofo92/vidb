module Tv
  class Channel < ApplicationRecord
    has_many :guide_channels, dependent: :restrict_with_error

    validates :display_name, presence: true
  end
end
