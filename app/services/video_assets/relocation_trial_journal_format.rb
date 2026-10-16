# frozen_string_literal: true

require 'time'

module VideoAssets
  class RelocationTrialJournalFormat
    IDENTITY_KEYS = %w[dev ino size mtime_ns ctime_ns].freeze
    TRANSITIONS = {
      nil => %w[prepared needs_review],
      'prepared' => %w[filesystem_renamed needs_review database_recovery_started],
      'filesystem_renamed' => %w[completed needs_review database_recovery_started],
      'completed' => %w[needs_review],
      'needs_review' => %w[database_recovery_started],
      'database_recovery_started' => %w[database_recovery_completed database_recovery_failed],
      'database_recovery_failed' => %w[database_recovery_started],
      'database_recovery_completed' => []
    }.freeze

    def initialize(directory, error:)
      @directory = directory
      @error = error
    end

    def validate_events!(events)
      previous = nil
      has_prepared = false
      events.each do |entry|
        validate_event!(entry, previous, has_prepared)
        has_prepared = true if entry['event'] == 'prepared'
        previous = entry['event']
      end
    end

    def validate_prepared!(entry)
      validate_record_identity!(entry)
      raise @error, 'Invalid source or target path' unless %w[source target].all? { |key| valid_path?(entry[key]) }
      raise @error, 'Source and target are identical' if entry['source'] == entry['target']
      return if valid_identity?(entry['identity'])

      raise @error, 'Invalid file identity'
    end

    private

    def validate_event!(entry, previous, has_prepared)
      raise @error, 'Invalid journal event sequence' unless valid_event?(entry, previous)
      if entry['event'].start_with?('database_recovery_') && !has_prepared
        raise @error, 'Recovery event without a prepared plan'
      end

      Time.iso8601(entry['at'])
    rescue ArgumentError
      raise @error, 'Invalid journal timestamp'
    end

    def valid_event?(entry, previous)
      entry.is_a?(Hash) && TRANSITIONS.fetch(previous).include?(entry['event']) && entry['at'].is_a?(String)
    end

    def validate_record_identity!(entry)
      return if %w[asset_id record_id].all? { |key| entry[key].is_a?(Integer) && entry[key].positive? }

      raise @error, 'Invalid asset or record identity'
    end

    def valid_path?(value)
      return false unless value.is_a?(String) && !value.include?("\0")

      @directory.direct_path?(Pathname.new(value)) && File.extname(value).downcase == '.mkv'
    end

    def valid_identity?(expected)
      expected.is_a?(Hash) && IDENTITY_KEYS.all? { |key| expected[key].is_a?(Integer) && expected[key] >= 0 }
    end
  end
end
