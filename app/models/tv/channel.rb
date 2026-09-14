module Tv
  class Channel < ApplicationRecord
    validates :display_name, presence: true
  end
end
