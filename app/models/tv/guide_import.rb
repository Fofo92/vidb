module Tv
  class GuideImport < ApplicationRecord
    belongs_to :guide_source

    enum :status,
         {
           running: "running",
           succeeded: "succeeded",
           failed: "failed"
         },
         prefix: true,
         default: :running

    validates :document_sha256,
              presence: true,
              format: { with: /\A[0-9a-f]{64}\z/i }
    validates :document_byte_size,
              numericality: {
                only_integer: true,
                greater_than_or_equal_to: 0
              }
    validates :document_sha256,
              uniqueness: {
                scope: :guide_source_id,
                conditions: -> { where(status: "succeeded") }
              },
              if: :status_succeeded?
  end
end
