module Tv
  class RecordingSchedulePlan
    Result = Data.define(:attributes, :existing_schedule) do
      def already_scheduled?
        !existing_schedule.nil?
      end
    end

    def initialize(recording_intent:, client:)
      @recording_intent = recording_intent
      @client = client
    end

    def call
      builder = RecordingIntentScheduleAttributes.new(recording_intent: @recording_intent)
      attributes = builder.call
      matcher = KaffeineScheduleMatcher.new(schedules: @client.schedules)
      existing = existing_schedule(matcher, attributes, builder.base_name)

      Result.new(attributes:, existing_schedule: existing)
    end

    private

    def existing_schedule(matcher, attributes, base_name)
      programme = @recording_intent.broadcast_observation
      old_episode = ProgrammeEpisodeLabel.legacy(programme)
      previous_name = "#{base_name} — #{old_episode}" if old_episode
      names = [attributes.fetch(:name), previous_name, base_name].compact.uniq

      names.each do |name|
        found = matcher.find(attributes.merge(name:))
        return found if found
      end

      nil
    end
  end
end
