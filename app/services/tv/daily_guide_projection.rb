module Tv
  class DailyGuideProjection
    def initialize(
      duration_minutes:,
      programme_ranges:,
      pixels_per_minute:,
      minimum_programme_height:
    )
      @duration_minutes = duration_minutes
      @programme_ranges = programme_ranges
      @pixels_per_minute = pixels_per_minute
      @minimum_programme_height = minimum_programme_height
      @positions = build_positions
    end

    def position_for(minute)
      @positions.fetch(minute)
    end

    def height_between(starts_at, ends_at)
      position_for(ends_at) - position_for(starts_at)
    end

    private

    def build_positions
      positions = [0]

      1.upto(@duration_minutes) do |minute|
        positions << position_at(minute, positions)
      end

      positions
    end

    def position_at(minute, positions)
      position = positions.fetch(minute - 1) + @pixels_per_minute

      ranges_ending_at(minute).each do |range|
        minimum_end = positions.fetch(range.first) +
                      @minimum_programme_height
        position = [position, minimum_end].max
      end

      position
    end

    def ranges_ending_at(minute)
      ranges_by_end.fetch(minute, [])
    end

    def ranges_by_end
      @ranges_by_end ||= @programme_ranges.group_by(&:last)
    end
  end
end
