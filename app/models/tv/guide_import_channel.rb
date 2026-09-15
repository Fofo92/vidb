module Tv
  class GuideImportChannel < ApplicationRecord
    COUNTER_FIELDS = %i[
      programme_count
      gap_count
      total_gap_duration_seconds
    ].freeze

    belongs_to :guide_import
    belongs_to :guide_channel

    validates :guide_channel,
              uniqueness: { scope: :guide_import_id }
    validates(*COUNTER_FIELDS,
              numericality: {
                only_integer: true,
                greater_than_or_equal_to: 0
              })

    validate :validate_json_collections
    validate :validate_coverage_interval
    validate :validate_gap_summary

    private

    def validate_json_collections
      %i[display_names gaps].each do |field|
        next if public_send(field).is_a?(Array)

        errors.add(field, "doit être une collection")
      end
    end

    def validate_coverage_interval
      if programme_count.to_i.positive?
        validate_present_coverage_interval
      elsif first_starts_at.present? || last_ends_at.present?
        errors.add(
          :base,
          "une couverture vide ne doit pas avoir d’intervalle"
        )
      end
    end

    def validate_present_coverage_interval
      errors.add(:first_starts_at, "doit être renseigné") if first_starts_at.blank?
      errors.add(:last_ends_at, "doit être renseigné") if last_ends_at.blank?
      return if first_starts_at.blank? || last_ends_at.blank?
      return if last_ends_at > first_starts_at

      errors.add(:last_ends_at, "doit suivre le début de la couverture")
    end

    def validate_gap_summary
      return unless gaps.is_a?(Array)
      return errors.add(:gaps, "contient une lacune invalide") unless valid_gaps?
      return if gap_summary_consistent?

      errors.add(:gaps, "ne correspond pas aux totaux annoncés")
    end

    def valid_gaps?
      gaps.all? do |gap|
        gap.is_a?(Hash) &&
          gap["duration_seconds"].is_a?(Integer) &&
          gap["duration_seconds"] >= 0
      end
    end

    def gap_summary_consistent?
      gap_count == gaps.size &&
        total_gap_duration_seconds == gaps.sum do |gap|
          gap["duration_seconds"]
        end
    end
  end
end
