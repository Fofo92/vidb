module Tv
  class Channel < ApplicationRecord
    has_many :guide_channels, dependent: :restrict_with_error

    validates :display_name, presence: true
    validates :logical_number,
              numericality: {
                only_integer: true,
                greater_than: 0
              },
              uniqueness: true,
              allow_nil: true
  end
end
