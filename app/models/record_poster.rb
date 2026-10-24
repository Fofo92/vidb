# frozen_string_literal: true

# Separate owner: changing artwork must never run the record's state callbacks.
class RecordPoster < ApplicationRecord
  MAX_BYTES = 5.megabytes
  CONTENT_TYPES = %w[image/jpeg image/png image/webp].freeze

  belongs_to :record, touch: false
  has_one_attached :image

  validate :acceptable_image

  private

  def acceptable_image
    return unless image.attached?

    errors.add(:image, "doit être une image JPEG, PNG ou WebP") unless CONTENT_TYPES.include?(image.blob.content_type)
    errors.add(:image, "doit peser au plus 5 Mo") if image.blob.byte_size > MAX_BYTES
  end
end
