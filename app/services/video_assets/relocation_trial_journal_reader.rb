# frozen_string_literal: true

require 'json'

module VideoAssets
  class RelocationTrialJournalReader
    MAX_BYTES = 1_048_576

    def initialize(format, error:)
      @format = format
      @error = error
    end

    def call(path)
      events = File.open(path, File::RDONLY | File::NOFOLLOW | File::NONBLOCK) { |file| read_events(file) }
      @format.validate_events!(events)
      events
    rescue SystemCallError => e
      raise @error, "Journal cannot be read: #{e.class}"
    end

    private

    def read_events(file)
      before = file.stat
      validate_file!(before)
      text = file.read(MAX_BYTES + 1)
      validate_read!(text, before, file.stat)
      text.lines.map { |line| JSON.parse(line) }
    end

    def validate_file!(stat)
      raise @error, 'Journal is not a regular file' unless stat.file?
      raise @error, 'Journal is too large' if stat.size > MAX_BYTES
    end

    def validate_read!(text, before, after)
      raise @error, 'Journal is too large' if text.bytesize > MAX_BYTES
      unless RelocationFileIdentity.signature(before) == RelocationFileIdentity.signature(after)
        raise @error, 'Journal changed while being read'
      end
      return unless text.empty? || !text.end_with?("\n")

      raise @error, 'Journal is empty or has an incomplete final line'
    end
  end
end
