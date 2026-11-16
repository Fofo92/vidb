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
    details = effective_condition
    details['integrality'] == 'complete' && !Array(details['presumed_fields']).include?('integrality')
  end

  def copy_condition_valid?(details = condition_details)
    details.is_a?(Hash) && condition_values_valid?(details) && condition_duration_valid?(details)
  end

  def condition_information_protected?
    condition_details.present? && !VideoAssets::DefaultConditionDocument.only_presumptions?(condition_details)
  end

  private

  def capture_initial_condition
    return if condition_details.present?

    markers = VideoAssets::LegacyConditionMarkers.call(last_known_path)
    self.condition_details = VideoAssets::DefaultConditionDocument.for_asset(self) || markers
  end

  def validate_copy_condition
    errors.add(:condition_details, 'est invalide ou contradictoire') unless copy_condition_valid?
  end

  def condition_values_valid?(details)
    choices = { 'integrality' => INTEGRALITY, 'damage' => DAMAGE, 'retained_portion' => PORTIONS }
    choices.all? { |key, values| values.include?(details.fetch(key, 'unknown')) } &&
      details.fetch('note', '').is_a?(String) && details.fetch('note', '').length <= 2000 &&
      details.fetch('evidence', []).is_a?(Array) && details.fetch('evidence', []).all?(Hash) &&
      [true, false].include?(details.fetch('needs_review', false)) && condition_presumptions_valid?(details)
  end

  def condition_presumptions_valid?(details)
    fields = details.fetch('presumed_fields', [])
    fields.is_a?(Array) && (fields - %w[integrality damage]).empty?
  end

  def condition_duration_valid?(details)
    seconds = details['retained_duration_seconds']
    valid = seconds.nil? || (seconds.is_a?(Integer) && seconds.positive? && seconds <= 86_400)
    return false unless valid
    return true if details.fetch('integrality', 'unknown') == 'incomplete'

    seconds.nil? && details.fetch('retained_portion', 'unknown') == 'unknown'
  end
end
