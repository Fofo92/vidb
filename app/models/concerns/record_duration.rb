# frozen_string_literal: true

module RecordDuration
  extend ActiveSupport::Concern

  included do
    validates :length_in_mn, allow_nil: true,
                             numericality: { greater_than_or_equal_to: :minimum_catalogue_length,
                                             less_than_or_equal_to: 240, only_integer: true }
  end

  def minimum_catalogue_length
    return 10 unless record_kind_episode?
    return 3 if genders.any? { |genre| genre.name.casecmp?('Animation') }

    animated_series? ? 3 : 10
  end

  private

  def animated_series?
    ancestors.where(record_kind: %w[series season]).joins(:genders)
             .where('LOWER(genders.name) = ?', 'animation').exists?
  end
end
