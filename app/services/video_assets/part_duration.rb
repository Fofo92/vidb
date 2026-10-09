# frozen_string_literal: true

module VideoAssets
  class PartDuration
    def self.range(copies, expected_parts:)
      whole = copies.select { |asset| asset.broadcast_part_number.nil? }
      durations = whole.filter_map(&:duration_minutes).minmax.compact
      values = durations + parts_range(copies, expected_parts)
      values.minmax if values.any?
    end

    def self.parts_range(copies, expected_parts)
      return [] if expected_parts <= 1

      groups = part_groups(copies)
      return [] unless groups.keys.sort == (1..expected_parts).to_a

      sum_ranges(groups.values.map { |assets| seconds_range(assets) })
    end

    def self.part_groups(copies)
      parts = copies.reject { |asset| asset.broadcast_part_number.nil? }
      parts.group_by(&:broadcast_part_number)
    end

    def self.seconds_range(assets)
      assets.filter_map { |asset| seconds(asset) }.minmax
    end

    def self.sum_ranges(ranges)
      return [] if ranges.any? { |range| range.first.nil? }

      [ranges.sum(&:first), ranges.sum(&:last)].map do |duration|
        (duration / 60.0).round
      end
    end

    def self.seconds(asset)
      measured = asset.technical_details['measured_duration_seconds']&.to_f
      return measured if measured&.positive?

      asset.duration_minutes * 60 if asset.duration_minutes
    end

    private_class_method :parts_range, :part_groups, :seconds_range, :sum_ranges, :seconds
  end
end
