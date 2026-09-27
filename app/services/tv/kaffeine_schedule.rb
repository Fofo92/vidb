module Tv
  KaffeineSchedule = Data.define(
    :key, :name, :channel, :starts_at, :duration_seconds, :repeat, :non_inactive
  )
end
