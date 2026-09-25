module Tv
  class RecordingIntent < ApplicationRecord
    belongs_to :broadcast_observation

    PADDING_FIELDS = %i[
      requested_padding_before_seconds
      requested_padding_after_seconds
      effective_padding_before_seconds
      effective_padding_after_seconds
    ].freeze

    enum :status, { selected: "selected", cancelled: "cancelled" },
         prefix: true, default: :selected

    validates(*PADDING_FIELDS, numericality: { only_integer: true, greater_than_or_equal_to: 0 })
    validates :programme_starts_at, :programme_ends_at, presence: true
    validates :broadcast_observation, uniqueness: true

    validate :validate_programme_interval

    before_validation :snapshot_programme_times, on: :create

    def capture_starts_at
      programme_starts_at - effective_padding_before_seconds.seconds
    end

    def capture_ends_at
      programme_ends_at + effective_padding_after_seconds.seconds
    end

    private

    def validate_programme_interval
      return if programme_starts_at.blank? || programme_ends_at.blank?
      return if programme_ends_at > programme_starts_at

      errors.add(
        :programme_ends_at,
        "doit suivre le début du programme"
      )
    end

    def snapshot_programme_times
      return unless broadcast_observation

      self.programme_starts_at ||= broadcast_observation.starts_at
      self.programme_ends_at ||= broadcast_observation.ends_at
    end
  end
end
