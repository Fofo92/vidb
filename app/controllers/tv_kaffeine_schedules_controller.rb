class TvKaffeineSchedulesController < ApplicationController
  def index
    @schedules = Tv::KaffeineDbus.new.schedules.sort_by { |schedule| [schedule.starts_at, schedule.key] }
    @links_by_key = Tv::KaffeineScheduleLink.active.where(
      kaffeine_key: @schedules.map(&:key)
    ).index_by(&:kaffeine_key)
  rescue Tv::KaffeineCommandRunner::CommandError,
         Tv::KaffeineScheduleParser::InvalidResponse => e
    Rails.logger.warn("Kaffeine schedule listing failed: #{e.class}: #{e.message}")
    @schedules = []
    @links_by_key = {}
    @kaffeine_unavailable = true
  end
end
