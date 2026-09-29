module Tv
  class ScheduledEpisodeDuplicates
    def initialize(schedules: nil)
      @schedules = schedules
    end

    def call(programmes)
      grouped = scheduled_intents.group_by do |intent|
        ProgrammeEpisodeKey.call(intent.broadcast_observation)
      end

      programmes.each_with_object({}) do |programme, matches|
        key = ProgrammeEpisodeKey.call(programme)
        next unless key

        other = grouped[key]&.find { |intent| other_broadcast?(intent, programme) && live_link?(intent) }
        matches[programme.id] = other if other
      end
    end

    private

    def other_broadcast?(intent, programme)
      intent.broadcast_observation_id != programme.id
    end

    def scheduled_intents
      RecordingIntent.status_selected.joins(:kaffeine_schedule_link)
                     .where("tv_recording_intents.programme_ends_at > ?", Time.current)
                     .includes(:broadcast_observation, :kaffeine_schedule_link)
                     .order(:programme_starts_at, :id)
    end

    def live_link?(intent)
      return true unless @schedules

      link = intent.kaffeine_schedule_link
      schedule = @schedules.find { |entry| entry.key == link.kaffeine_key }
      schedule && link.matches?(schedule)
    end
  end
end
