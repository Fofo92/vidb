class LanguageVersion < ApplicationRecord
  has_many :records
  validates :long_name, presence: true
  validates :short_name, presence: true, uniqueness: true

  def silent?
    short_name.to_s.casecmp?('MUET') || long_name.to_s.casecmp?('Muet')
  end
end
