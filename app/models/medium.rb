class Medium < ApplicationRecord
end
class Medium < ApplicationRecord
  validates :short_name, presence: true
  validates :long_name, presence: true
end
