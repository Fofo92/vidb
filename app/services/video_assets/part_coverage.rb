# frozen_string_literal: true

module VideoAssets
  # Several encodings of the same part never increase coverage.
  class PartCoverage
    def self.available?(assets, expected_parts:)
      present = assets.select(&:status_present?)
      recorded?(present, expected_parts: expected_parts)
    end

    def self.recorded?(assets, expected_parts:)
      return true if assets.any? { |asset| asset.broadcast_part_number.nil? }
      return false if expected_parts <= 1

      numbers = assets.map(&:broadcast_part_number).uniq.sort
      numbers == (1..expected_parts).to_a
    end
  end
end
