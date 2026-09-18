module Tv
  class DailyGuide
    def initialize(guide_source:, date:)
      @guide_source = guide_source
      @date = date
    end

    def call
      guide_import = @guide_source.latest_successful_import
      return BroadcastObservation.none unless guide_import

      guide_import.broadcast_observations
                  .where("starts_at < ? AND ends_at > ?", day_end, day_start)
                  .order(:starts_at, :id)
    end

    private

    def day_start
      midnight(@date)
    end

    def day_end
      midnight(@date.next_day)
    end

    def midnight(date)
      Time.find_zone!("Europe/Paris").local(
        date.year, date.month, date.day
      )
    end
  end
end
