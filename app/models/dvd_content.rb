class DvdContent < ApplicationRecord
  belongs_to :dvd_edition
  belongs_to :record
  belongs_to :language_version, optional: true

  after_save :mark_dvd_support

  validates :record_id, uniqueness: { scope: :dvd_edition_id }
  validates :audio_languages, :subtitle_languages, length: { maximum: 300 }

  private

  def mark_dvd_support
    DvdOwnership.mark_support!(record)
  end
end
