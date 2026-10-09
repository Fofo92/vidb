# frozen_string_literal: true

require 'json'
require 'digest'
require 'tempfile'

module VideoAssets
  class ReconciliationJournal
    def initialize(directory:, automatic: false)
      @directory = Pathname.new(directory)
      @archive_directory = automatic ? @directory.join('automatic-history') : @directory
      @retention = automatic ? 32 : nil
    end

    def call(report:)
      @directory.mkpath
      File.open(@directory.join('followup.lock'), File::RDWR | File::CREAT, 0o600) do |lock|
        lock.flock(File::LOCK_EX)
        persist(report)
      end
    end

    private

    def persist(report)
      ledger = @directory.join('current.json')
      previous = ledger.exist? ? JSON.parse(ledger.read) : nil
      followup = ReconciliationFollowup.new(report: report, previous: previous).call
      archive('source', JSON.pretty_generate(report) << "\n")
      payload = JSON.pretty_generate(followup) << "\n"
      archive('followup', payload)
      replace(ledger, payload)
      prune_archives
      followup
    end

    def archive(prefix, payload)
      @archive_directory.mkpath
      path = @archive_directory.join("#{prefix}-#{Digest::SHA256.hexdigest(payload)}.json")
      replace(path, payload) unless path.exist?
    end

    def prune_archives
      return unless @retention

      %w[source followup].each do |prefix|
        paths = @archive_directory.glob("#{prefix}-*.json").sort_by(&:mtime).reverse
        paths.drop(@retention).each(&:delete)
      end
    end

    def replace(path, payload)
      Tempfile.create(['followup-', '.json'], @directory.to_s) do |file|
        file.chmod(0o600)
        file.write(payload)
        file.flush
        file.fsync
        File.rename(file.path, path)
      end
    end
  end
end
