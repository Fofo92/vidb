class DvdPreparation < ApplicationRecord
  has_one :dvd_edition, primary_key: :ean, foreign_key: :ean, inverse_of: false

  validates :provisional_title, length: { maximum: 300 }
  validates :notes, length: { maximum: 5000 }
  validates :announced_content_count, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :lookup_status, inclusion: { in: %w[pending found not_found unavailable] }
  validate :valid_ean

  scope :awaiting_identification, -> { where.missing(:dvd_edition) }

  def display_title
    record = dvd_edition&.record
    record&.french_title.presence || record&.original_title.presence ||
      provisional_title.presence || external_titles.first.presence || "Coffret à identifier"
  end

  def preparation_status
    dvd_edition ? "Identification confirmée" : "À identifier"
  end

  private

  def valid_ean
    errors.add(:ean, "doit être un EAN-13 valide") unless DvdEdition.valid_ean?(ean)
  end
end
