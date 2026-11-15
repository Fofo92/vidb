# frozen_string_literal: true

class RecordRatingUpdate
  def self.call(record:, user:, value:)
    record.with_lock do
      if value.nil?
        RecordRating.find_by(record: record, user: user)&.destroy!
      else
        rating = RecordRating.find_or_initialize_by(record: record, user: user)
        rating.update!(value: value)
      end
    end
    record.reload
  end
end
