class LanguageVersion < ApplicationRecord
  has_many :records, dependent: :nullify
  validates :long_name, presence: true
  validates :short_name, presence: true, uniqueness: true
end
