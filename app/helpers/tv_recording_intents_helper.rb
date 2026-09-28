module TvRecordingIntentsHelper
  include TvGuidesHelper

  def recording_intent_channel_name(recording_intent)
    guide_channel =
      recording_intent.broadcast_observation.guide_channel

    guide_channel.channel&.display_name ||
      guide_channel.external_id
  end

  def recording_intent_title(recording_intent)
    programme = recording_intent.broadcast_observation
    title = tv_programme_title(programme).presence || "Programme sans titre"
    episode = tv_programme_episode(programme)

    episode ? "#{title} — #{episode}" : title
  end

  def recording_intent_time(time)
    time.in_time_zone("Europe/Paris").strftime("%H:%M")
  end

  def recording_intent_date_heading(date)
    I18n.l(date, format: "%-d %B %Y", locale: :fr)
  end
end
