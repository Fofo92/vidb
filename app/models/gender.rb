class Gender < ApplicationRecord
  has_and_belongs_to_many :records
  validates :name, presence: true, uniqueness: true

  def number_of_records_per_gender(id)
    # returns number of records associated to Gender(id)
    Gender.find(id).records.count
  end
end
