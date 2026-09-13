module Tv
  class XmltvCoverage
    def initialize(programmes)
      @programmes = programmes
    end

    def call
      @programmes
        .group_by(&:channel_id)
        .transform_values { |programmes| coverage_for(programmes) }
    end

    private

    def coverage_for(programmes)
      ordered_programmes = programmes.sort_by(&:starts_at)

      XmltvChannelCoverage.new(
        channel_id: ordered_programmes.first.channel_id,
        programme_count: ordered_programmes.size,
        starts_at: ordered_programmes.first.starts_at,
        ends_at: ordered_programmes.map(&:ends_at).max,
        gaps: gaps_for(ordered_programmes)
      )
    end

    def gaps_for(programmes)
      covered_until = programmes.first.ends_at

      programmes.drop(1).filter_map do |programme|
        gap = coverage_gap(covered_until, programme.starts_at)
        covered_until = [covered_until, programme.ends_at].max
        gap
      end
    end

    def coverage_gap(covered_until, next_start)
      return unless next_start > covered_until

      XmltvCoverageGap.new(
        starts_at: covered_until,
        ends_at: next_start
      )
    end
  end
end
