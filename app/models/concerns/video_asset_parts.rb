# frozen_string_literal: true

module VideoAssetParts
  extend ActiveSupport::Concern

  included do
    validates :broadcast_part_number, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
    validate :validate_broadcast_part_number
    validate :preserve_broadcast_part_identity
  end

  private

  def validate_broadcast_part_number
    return if broadcast_part_number.nil? || record.nil?
    return if record.broadcast_part_count > 1 && broadcast_part_number <= record.broadcast_part_count

    errors.add(:broadcast_part_number, 'ne correspond pas au découpage déclaré de l’épisode')
  end

  def preserve_broadcast_part_identity
    return unless persisted? && will_save_change_to_broadcast_part_number?

    errors.add(:broadcast_part_number, 'ne peut pas changer pour une copie confirmée')
  end
end
