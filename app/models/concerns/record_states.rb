# frozen_string_literal: true

module RecordStates
  extend ActiveSupport::Concern

  FIELDS = %i[is_recorded is_available is_seen is_checked].freeze

  included do
    before_validation :preserve_recording_history
  end

  def state_container?
    %w[series season].include?(record_kind) || (persisted? && has_children?)
  end

  def state_leaves
    return state_container? ? [] : [self] unless persisted? && has_children?

    records = descendants.includes(:video_assets).to_a
    parent_ids = records.filter_map { |item| item.ancestry.to_s.split('/').last&.to_i }
    records.reject { |item| parent_ids.include?(item.id) || %w[series season].include?(item.record_kind) }
  end

  def state_counts
    leaves = state_leaves
    FIELDS.to_h do |field|
      values = leaves.map { |leaf| leaf.effective_state(field) }
      [field, { yes: values.count(true), no: values.count(false), unknown: values.count(nil), total: leaves.length }]
    end
  end

  def effective_state(field)
    raise ArgumentError, 'Unsupported state' unless FIELDS.include?(field)

    assets = video_assets.to_a
    observed = asset_state(field, assets)
    return observed unless observed.nil?

    value = public_send(field)
    unverified_negative?(field, value) ? nil : value
  end

  def refresh_video_asset_states!
    return if state_container?

    with_lock do
      recorded = is_recorded == true || recorded_video_asset_coverage?(video_assets.reload.to_a)
      update!(is_recorded: recorded, is_available: complete_video_asset_coverage?)
    end
  end

  private

  def asset_state(field, assets)
    return complete_video_asset_coverage?(assets) if field == :is_available && assets.any?
    return true if field == :is_recorded && recorded_video_asset_coverage?(assets)

    nil
  end

  def unverified_negative?(field, value)
    return false if field == :is_seen && seen_state_confirmed_at.present?

    value == false && field != :is_checked && is_checked != true
  end

  def preserve_recording_history
    return if state_container?

    self.is_recorded = true if is_recorded_in_database == true || is_available == true
    return unless persisted? && video_assets.exists?

    self.is_recorded = true if recorded_video_asset_coverage?(video_assets.reload.to_a)
    self.is_available = complete_video_asset_coverage?
  end

  def complete_video_asset_coverage?(assets = video_assets.reload.to_a)
    VideoAssets::PartCoverage.available?(assets, expected_parts: broadcast_part_count)
  end

  def recorded_video_asset_coverage?(assets)
    is_available == true || VideoAssets::PartCoverage.recorded?(assets, expected_parts: broadcast_part_count)
  end
end
