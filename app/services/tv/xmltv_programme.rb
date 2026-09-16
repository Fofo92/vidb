module Tv
  XmltvProgramme = Data.define(
    :channel_id,
    :starts_at,
    :ends_at,
    :source_start,
    :source_stop,
    :titles,
    :subtitles,
    :descriptions,
    :categories,
    :episode_numbers
  )
end
