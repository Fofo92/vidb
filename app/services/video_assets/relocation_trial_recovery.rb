# frozen_string_literal: true

require 'json'
require 'time'

module VideoAssets
  # Test environment only. Updates the existing database row, never the files.
  # Metadata identity has the same limits as RelocationTrialInspection.
  class RelocationTrialRecovery
    class Refused < StandardError; end

    class Failed < StandardError
      attr_reader :journal_path

      def initialize(journal_path)
        @journal_path = journal_path.to_s
        super("Trial database recovery requires inspection; journal: #{journal_path}")
      end
    end

    def initialize(root:, writer: nil)
      @inspector = RelocationTrialInspection.new(root: root)
      @writer = writer || ->(asset, target) { asset.update!(last_known_path: target) }
    end

    def call(journal_path:)
      validate_environment!

      initial = @inspector.call(journal_path: journal_path)
      RelocationTrialRecoverySession.validate_state!(initial)
      File.open(journal_path, File::RDWR | File::APPEND | File::NOFOLLOW | File::NONBLOCK) do |journal|
        raise Refused, 'Journal is not a regular file' unless journal.stat.file?
        raise Refused, 'Another recovery holds the journal lock' unless journal.flock(File::LOCK_EX | File::LOCK_NB)

        RelocationTrialRecoverySession.new(@inspector, @writer, journal, journal_path, initial.fetch(:prepared)).call
      end
    end

    private

    def validate_environment!
      raise Refused, 'Recovery is restricted to the Rails test environment' unless Rails.env.test?
      return unless VideoAsset.connection.transaction_open?

      raise Refused,
            'An outer database transaction prevents commit verification'
    end
  end
end
