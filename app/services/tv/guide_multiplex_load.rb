module Tv
  class GuideMultiplexLoad
    CAPTURE_START_SQL = "programme_starts_at - effective_padding_before_seconds * INTERVAL '1 second' < ?"
    CAPTURE_END_SQL = "programme_ends_at + effective_padding_after_seconds * INTERVAL '1 second' > ?"

    Capture = Data.define(:intent_id, :starts_at, :ends_at, :channel, :title, :multiplex)
    Segment = Data.define(:starts_at, :ends_at, :start_minute, :end_minute, :multiplexes, :unknown_channels, :captures)

    def initialize(date:, guide_source:, intents: nil)
      zone = Time.find_zone!("Europe/Paris")
      @day_start = zone.local(date.year, date.month, date.day)
      next_day = date.next_day
      @day_end = zone.local(next_day.year, next_day.month, next_day.day)
      @guide_source = guide_source
      @intents = intents
    end

    def call
      captures = selected_intents.filter_map { |intent| capture(intent) }
      boundaries = ([@day_start, @day_end] + captures.flat_map { |entry| [entry.starts_at, entry.ends_at] }).uniq.sort
      boundaries.each_cons(2).map do |starts_at, ends_at|
        active = captures.select { |entry| entry.starts_at <= starts_at && entry.ends_at > starts_at }
        segment(starts_at, ends_at, active)
      end
    end

    private

    def selected_intents
      return @intents if @intents
      return [] unless @guide_source

      RecordingIntent.status_selected.joins(broadcast_observation: :guide_channel)
                     .where(tv_guide_channels: { guide_source_id: @guide_source.id })
                     .where(CAPTURE_START_SQL, @day_end)
                     .where(CAPTURE_END_SQL, @day_start)
                     .includes(broadcast_observation: { guide_channel: :channel })
    end

    def capture(intent)
      return unless intent.status_selected?

      window = capture_window(intent)
      starts_at = window.first
      ends_at = window.last
      return unless starts_at < ends_at

      channel = capture_channel(intent)
      Capture.new(intent_id: intent.id, starts_at:, ends_at:, channel:,
                  title: ProgrammeDisplayName.call(intent.broadcast_observation), multiplex: multiplex(channel))
    end

    def capture_window(intent)
      [[intent.capture_starts_at, @day_start].max, [intent.capture_ends_at, @day_end].min]
    end

    def capture_channel(intent)
      guide_channel = intent.broadcast_observation.guide_channel
      channel = guide_channel.channel
      channel&.kaffeine_name.presence || channel&.display_name || guide_channel.external_id
    end

    def multiplex(channel)
      MultiplexCapacityGuard::MULTIPLEXES.find { |_number, names| names.include?(channel) }&.first
    end

    def segment(starts_at, ends_at, captures)
      multiplexes = captures.filter_map(&:multiplex).uniq.sort
      unknown_channels = captures.reject(&:multiplex).map(&:channel).uniq.sort
      Segment.new(starts_at:, ends_at:, start_minute: minutes(starts_at), end_minute: minutes(ends_at),
                  multiplexes:, unknown_channels:, captures: captures.sort_by(&:intent_id))
    end

    def minutes(time)
      (time - @day_start) / 60.0
    end
  end
end
