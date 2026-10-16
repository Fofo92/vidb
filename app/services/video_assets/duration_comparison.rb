# frozen_string_literal: true

module VideoAssets
  class DurationComparison
    def initialize(catalogue:, copies:, expected_parts: 1)
      @catalogue = catalogue
      @copies = copies
      @expected_parts = expected_parts
    end

    def concordant?
      return false unless @catalogue&.positive? && measured? && complete_parts?

      range = PartDuration.range(@copies, expected_parts: @expected_parts)
      range&.all? { |minutes| (minutes - @catalogue).abs * 100 < @catalogue * 10 }
    end

    private

    def measured?
      @copies.any? && @copies.all? { |copy| copy.duration_minutes&.positive? }
    end

    def complete_parts?
      parts = @copies.filter_map(&:broadcast_part_number).uniq.sort
      parts.empty? || (@expected_parts > 1 && parts == (1..@expected_parts).to_a)
    end
  end
end
