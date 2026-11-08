class DvdContent < ApplicationRecord
  belongs_to :dvd_edition
  belongs_to :record
  belongs_to :language_version, optional: true

  validates :record_id, uniqueness: { scope: :dvd_edition_id }
  validates :audio_languages, :subtitle_languages, length: { maximum: 300 }
end
