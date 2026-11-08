class DvdEdition < ApplicationRecord
  belongs_to :record
  has_many :dvd_contents, dependent: :destroy

  validate do
    errors.add(:ean, "doit être un EAN-13 valide") unless self.class.valid_ean?(ean)
  end

  def self.valid_ean?(ean)
    return false unless ean.is_a?(String) && ean.match?(/\A[0-9]{13}\z/)

    weighted_sum = ean.bytes.each_with_index.sum { |digit, index| (digit - 48) * (index.even? ? 1 : 3) }
    (weighted_sum % 10).zero?
  end
end
