module Tv
  class PreviouslyRecordedEpisodes
    def call(programmes)
      by_episode = confirmed_episodes

      programmes.each_with_object({}) do |programme, matches|
        key = episode_key(programme)
        intent = by_episode[key]&.select do |candidate|
          candidate.programme_ends_at < programme.starts_at
        end&.max_by(&:programme_starts_at)
        matches[programme.id] = intent if intent
      end
    end

    private

    def confirmed_episodes
      previous = RecordingIntent.status_selected.joins(:kaffeine_schedule_link)
                                .where.not(recording_verified_at: nil)
                                .includes(:broadcast_observation)
      previous.each_with_object({}) do |intent, matches|
        key = episode_key(intent.broadcast_observation)
        next unless key

        (matches[key] ||= []) << intent
      end
    end

    def episode_key(programme)
      title = ProgrammeDisplayName.title(programme)&.squish&.downcase
      entry = programme.episode_numbers.find { |number| number["system"] == "xmltv_ns" }
      episode = entry&.fetch("value", nil)&.match(/\A(\d+)\.(\d+)\./)
      return if title.blank? || !episode

      [title, episode[1].to_i, episode[2].to_i]
    end
  end
end
