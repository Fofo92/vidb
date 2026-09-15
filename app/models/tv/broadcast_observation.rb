module Tv
  class BroadcastObservation < ApplicationRecord
    belongs_to :guide_channel

    validates :fingerprint,
              presence: true,
              format: { with: /\A[0-9a-f]{64}\z/i },
              uniqueness: { scope: :fingerprint_version }
    validates :fingerprint_version,
              numericality: {
                only_integer: true,
                greater_than: 0
              }
    validates :starts_at, :ends_at, presence: true

    validate :validate_time_interval
    validate :validate_structured_metadata

    STRUCTURED_METADATA_FIELDS = %i[
      titles
      subtitles
      descriptions
      categories
      episode_numbers
    ].freeze

    private

    def validate_structured_metadata
      STRUCTURED_METADATA_FIELDS.each do |field|
        validate_metadata_field(field)
      end
    end

    def validate_metadata_field(field)
      entries = public_send(field)

      unless entries.is_a?(Array)
        errors.add(field, "doit être une collection")
        return
      end

      return if entries.all? do |entry|
        entry.is_a?(Hash) && entry["value"].present?
      end

      errors.add(field, "doit contenir des valeurs explicites")
    end

    def validate_time_interval
      return if starts_at.blank? || ends_at.blank?
      return if ends_at > starts_at

      errors.add(:ends_at, "doit suivre le début du programme")
    end
  end
end
