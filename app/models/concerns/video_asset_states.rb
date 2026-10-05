# frozen_string_literal: true

module VideoAssetStates
  extend ActiveSupport::Concern

  included do
    after_save :refresh_owner_states
    after_destroy :refresh_owner_states
    validate :preserve_asset_owner
  end

  private

  def refresh_owner_states
    record.refresh_video_asset_states!
  end

  def preserve_asset_owner
    return unless persisted? && will_save_change_to_record_id?

    errors.add(:record_id, 'ne peut pas être changé pour une copie confirmée')
  end
end
