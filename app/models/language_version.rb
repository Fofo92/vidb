class LanguageVersion < ApplicationRecord
  validates :long_name, presence: true
  validates :short_name, presence: true, uniqueness: true
end
