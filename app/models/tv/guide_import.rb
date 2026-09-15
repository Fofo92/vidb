module Tv
  class GuideImport < ApplicationRecord
    belongs_to :guide_source
    has_many :guide_import_observations, dependent: :restrict_with_error
    has_many :broadcast_observations, through: :guide_import_observations

    enum :status,
         {
           running: "running",
           succeeded: "succeeded",
           failed: "failed"
         },
         prefix: true,
         default: :running

    IMPORT_COUNTERS = %i[
      channel_count
      source_programme_count
      programme_count
      duplicate_programme_count
    ].freeze

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
    validates :started_at, presence: true
    validates(*IMPORT_COUNTERS,
              numericality: {
                only_integer: true,
                greater_than_or_equal_to: 0
              })
    validate :validate_completion
    validate :validate_error_message
    validate :validate_timeline

    before_validation :set_started_at, on: :create

    private

    def validate_completion
      if status_running?
        errors.add(:finished_at, "doit être absente") if finished_at.present?
      elsif finished_at.blank?
        errors.add(:finished_at, "doit être renseignée")
      end
    end

    def validate_error_message
      if status_failed?
        errors.add(:error_message, "doit être renseigné") if error_message.blank?
      elsif error_message.present?
        errors.add(:error_message, "doit être absent")
      end
    end

    def validate_timeline
      return if started_at.blank? || finished_at.blank?
      return unless finished_at < started_at

      errors.add(
        :finished_at,
        "ne peut pas précéder le début de l’import"
      )
    end

    def set_started_at
      self.started_at ||= Time.current
    end
  end
end
