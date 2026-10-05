class VideoAsset < ApplicationRecord
  include VideoAssetStates

  belongs_to :record, inverse_of: :video_assets

  enum :status,
       {
         present: "present",
         deleted: "deleted"
       },
       prefix: true,
       validate: true

  validates :last_known_path, presence: { if: :status_present? }
  validates :duration_minutes,
            allow_nil: true,
            numericality: { only_integer: true, greater_than: 0 }
  validates :byte_size,
            allow_nil: true,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
