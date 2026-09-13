module Tv
  XmltvProgramme = Data.define(
    :channel_id,
    :starts_at,
    :ends_at,
    :titles,
    :subtitles,
    :descriptions,
    :categories,
    :episode_numbers
  )
end
