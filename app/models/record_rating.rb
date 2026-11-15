# frozen_string_literal: true

# A personal catalogue opinion, separate from metadata and physical availability.
class RecordRating < ApplicationRecord
  belongs_to :record, inverse_of: :ratings
  belongs_to :user, inverse_of: :record_ratings

  validates :record_id, uniqueness: { scope: :user_id }
  validates :value, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 5 }
end
