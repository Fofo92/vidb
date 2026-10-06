module Tv
  class KaffeineScheduleLink < ApplicationRecord
    belongs_to :recording_intent

    enum :origin, { created_by_vidb: "created_by_vidb", preexisting: "preexisting" }, prefix: true

    scope :active, -> { where(retired_at: nil) }

    validates :recording_intent, uniqueness: true

    validates :kaffeine_key, uniqueness: { conditions: -> { active } }, if: -> { retired_at.nil? }
    validates :kaffeine_key,
              numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 4_294_967_295 }
    validates :name, :channel, :starts_at, presence: true
    validates :duration_seconds, numericality: { only_integer: true, greater_than: 0, less_than: 86_400 }
    validates :repeat_mask, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than: 128 }

    def self.attach!(recording_intent:, schedule:, origin:)
      KaffeineScheduleLinkAttachment.new(recording_intent:, schedule:, origin:).call
    end

    def retired?
      retired_at.present?
    end

    def matches?(schedule)
      !retired? && schedule.key == kaffeine_key &&
        schedule.name == name &&
        schedule.channel == channel &&
        schedule.starts_at == starts_at &&
        schedule.duration_seconds == duration_seconds &&
        schedule.repeat == repeat_mask
    end
  end
end
