class Medium < ApplicationRecord
end
class Medium < ApplicationRecord
  has_and_belongs_to_many :records
  validates :short_name, presence: true
  validates :long_name, presence: true
end
