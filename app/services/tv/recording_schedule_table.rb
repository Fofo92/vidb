module Tv
  # Joins selections to the live schedule by their recorded Kaffeine key.
  class RecordingScheduleTable
    Row = Data.define(:intent, :schedule, :state, :guide_missing) do
      def starts_at
        intent&.programme_starts_at || schedule.starts_at
      end

      def capture_ends_at
        live_end = schedule.starts_at + schedule.duration_seconds if schedule
        [intent&.capture_ends_at, live_end].compact.max
      end

      def channels
        guide = intent&.broadcast_observation&.guide_channel
        [guide&.channel&.display_name || guide&.external_id, schedule&.channel].compact
      end
    end

    STATES = {
      'linked' => 'Liée et concordante', 'vidb_only' => 'Sélection vidb seule',
      'kaffeine_only' => 'Kaffeine seule', 'review' => 'À vérifier',
      'history' => 'Programmation passée', 'offline' => 'Kaffeine indisponible'
    }.freeze

    attr_reader :unavailable

    def initialize(intents:, filters:, title:, client: KaffeineDbus.new)
      @intents = intents
      @filters = filters
      @title = title
      @client = client
    end

    def call
      schedules = live_schedules.index_by(&:key)
      @guide_gaps = ScheduleGuideGaps.new.call(@intents)
      rows = @intents.map { |intent| linked_row(intent, schedules) }
      rows.concat(schedules.values.map { |schedule| Row.new(nil, schedule, 'kaffeine_only', false) })
      rows.select { |row| visible?(row) }.sort_by(&:starts_at).reverse
    end

    private

    def live_schedules
      @client.schedules
    rescue KaffeineCommandRunner::CommandError, KaffeineScheduleParser::InvalidResponse, SystemCallError => e
      Rails.logger.warn("Kaffeine schedule listing failed: #{e.class}: #{e.message}")
      @unavailable = true
      []
    end

    def linked_row(intent, schedules)
      link = intent.kaffeine_schedule_link
      return Row.new(intent, nil, 'vidb_only', false) unless link
      return Row.new(intent, nil, 'history', false) if link.retired?

      missing = @guide_gaps.include?(intent.id)
      return Row.new(intent, nil, 'offline', missing) if unavailable

      schedule = schedules.delete(link.kaffeine_key)
      state = agrees?(intent, link, schedule) ? 'linked' : 'review'
      Row.new(intent, schedule, state, missing)
    end

    def agrees?(intent, link, schedule)
      return false unless schedule && link.matches?(schedule)

      expected = RecordingIntentScheduleAttributes.new(recording_intent: intent).call
      expected.all? { |field, value| schedule.public_send(field) == value }
    rescue RecordingIntentScheduleAttributes::Unavailable
      false
    end

    def visible?(row)
      return false if @filters[:history] != '1' && row.capture_ends_at <= Time.current
      return false unless date_matches?(row)
      return false unless state_matches?(row)

      titles = [row.intent && @title.call(row.intent), row.schedule&.name].compact
      matches?(titles, @filters[:q]) && matches?(row.channels, @filters[:channel])
    end

    def state_matches?(row)
      state = @filters[:state]
      state.blank? || row.state == state
    end

    def date_matches?(row)
      date = @filters[:date]
      date.blank? || row.starts_at.in_time_zone('Europe/Paris').to_date.iso8601 == date
    end

    def matches?(values, query)
      needle = I18n.transliterate(query.to_s.strip).downcase
      needle.empty? || values.any? { |value| I18n.transliterate(value).downcase.include?(needle) }
    end
  end
end
