# frozen_string_literal: true

module RecordPosters
  class Display
    def self.call(record)
      own = attached_poster(record)
      return own if own
      return unless %w[season episode].include?(record.record_kind)

      series = record.ancestors.to_a.select(&:record_kind_series?).last
      attached_poster(series) if series
    end

    def self.attached_poster(record)
      poster = record.record_poster
      poster if poster&.image&.attached?
    end
  end
end
