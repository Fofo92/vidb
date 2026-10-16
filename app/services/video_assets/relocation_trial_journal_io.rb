# frozen_string_literal: true

require 'json'
require 'time'

module VideoAssets
  module RelocationTrialJournalIo
    def self.append(journal, event, details = {})
      entry = details.merge(event: event, at: Time.now.utc.iso8601(6))
      journal.write("#{JSON.generate(entry)}\n")
      journal.flush
      journal.fsync
    end

    def self.record_failure(journal, event, error)
      append(journal, event, error_class: error.class.name, error_message: error.message)
    rescue StandardError
      # Keep the original failure even when its final journal entry cannot be written.
      nil
    end
  end
end
