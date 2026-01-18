class LanguageVersion < ApplicationRecord
  has_many :records
  validates :long_name, presence: true
  validates :short_name, presence: true, uniqueness: true
end
