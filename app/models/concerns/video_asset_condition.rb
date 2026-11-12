# frozen_string_literal: true

module VideoAssetCondition
  extend ActiveSupport::Concern

  INTEGRALITY = %w[unknown complete incomplete].freeze
  DAMAGE = %w[unknown none light severe].freeze
  PORTIONS = %w[unknown beginning end].freeze

  included do
    before_validation :capture_initial_condition, on: :create
    validate :validate_copy_condition
  end

  def effective_condition
    return condition_details if condition_details.present?

    VideoAssets::LegacyConditionMarkers.call(last_known_path)
  end

  def content_incomplete?
    effective_condition['integrality'] == 'incomplete'
  end

  def integrality_verified?
    effective_condition['integrality'] == 'complete'
  end

  private

  def capture_initial_condition
    return if condition_details.present?

    self.condition_details = VideoAssets::LegacyConditionMarkers.call(last_known_path)
  end

  def validate_copy_condition
    details = condition_details
    valid = details.is_a?(Hash) && condition_values_valid?(details) && condition_duration_valid?(details)
    errors.add(:condition_details, 'est invalide ou contradictoire') unless valid
  end

  def condition_values_valid?(details)
    choices = { 'integrality' => INTEGRALITY, 'damage' => DAMAGE, 'retained_portion' => PORTIONS }
    choices.all? { |key, values| values.include?(details.fetch(key, 'unknown')) } &&
      details.fetch('note', '').is_a?(String) && details.fetch('note', '').length <= 2000 &&
      details.fetch('evidence', []).is_a?(Array) && details.fetch('evidence', []).all?(Hash) &&
      [true, false].include?(details.fetch('needs_review', false))
  end

  def condition_duration_valid?(details)
    seconds = details['retained_duration_seconds']
    valid = seconds.nil? || (seconds.is_a?(Integer) && seconds.positive? && seconds <= 86_400)
    return false unless valid
    return true if details.fetch('integrality', 'unknown') == 'incomplete'

    seconds.nil? && details.fetch('retained_portion', 'unknown') == 'unknown'
  end
end
