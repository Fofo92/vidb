module Tv
  class DailyGuideTimeline
    Result = Data.define(
      :duration_minutes,
      :items,
      :ticks
    )
    Item = Data.define(
      :programme,
      :start_minute,
      :duration_minutes
    )
    Tick = Data.define(
      :minute,
      :label
    )

    def initialize(date:, programmes:)
      @date = date
      @programmes = programmes
    end

    def call
      Result.new(
        duration_minutes: minutes_between(day_start, day_end),
        items: items,
        ticks: ticks
      )
    end

    private

    def items
      @programmes.sort_by(&:starts_at).filter_map do |programme|
        item(programme)
      end
    end

    def item(programme)
      starts_at = [programme.starts_at, day_start].max
      ends_at = [programme.ends_at, day_end].min
      return unless ends_at > starts_at

      Item.new(
        programme: programme,
        start_minute: minutes_between(day_start, starts_at),
        duration_minutes: minutes_between(starts_at, ends_at)
      )
    end

    def ticks
      current_time = day_start
      result = []

      while current_time < day_end
        result << Tick.new(
          minute: minutes_between(day_start, current_time),
          label: current_time.strftime("%H:%M")
        )
        current_time += 1.hour
      end

      result
    end

    def day_start
      @day_start ||= midnight(@date)
    end

    def day_end
      @day_end ||= midnight(@date.next_day)
    end

    def midnight(date)
      Time.find_zone!("Europe/Paris").local(
        date.year,
        date.month,
        date.day
      )
    end

    def minutes_between(starts_at, ends_at)
      ((ends_at - starts_at) / 60).to_i
    end
  end
end
