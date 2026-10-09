# frozen_string_literal: true

module VideoAssets
  class ReconciliationRefresh
    def initialize(directory:, scanner:, guard: nil, reporter: nil, journal: nil)
      @directory = Pathname.new(directory)
      @scanner = scanner
      @root = '/videos'
      @guard = guard || ReconciliationVolumeGuard.new(root: @root)
      @reporter = reporter || ->(inventory) { ReconciliationReport.new(inventory: inventory).call }
      @journal = journal || ReconciliationJournal.new(directory: directory, automatic: true)
    end

    def call
      @directory.mkpath
      File.open(@directory.join('refresh.lock'), File::RDWR | File::CREAT, 0o600) do |lock|
        return { skipped: 'refresh_already_running' } unless lock.flock(File::LOCK_EX | File::LOCK_NB)

        refresh
      end
    end

    private

    def refresh
      consume_request
      @guard.call
      inventory = @scanner.call.deep_symbolize_keys
      validate_inventory!(inventory)
      @guard.call
      report = @reporter.call(inventory)
      @guard.call
      @journal.call(report: report)
    end

    def consume_request
      @directory.join('refresh.request').delete
    rescue Errno::ENOENT
      nil
    end

    def validate_inventory!(inventory)
      raise ArgumentError, 'Unexpected inventory scope' unless inventory.fetch(:roots) == [@root]

      errors = inventory.fetch(:entries).select { |entry| %w[missing_root inaccessible].include?(entry[:type]) }
      return if errors.empty?

      raise ArgumentError, "Incomplete scan: #{errors.first[:path]}; previous followup preserved"
    end
  end
end
