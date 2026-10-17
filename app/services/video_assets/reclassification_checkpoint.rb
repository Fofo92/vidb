# frozen_string_literal: true

module VideoAssets
  class ReclassificationCheckpoint
    EVENTS = %w[prepared filesystem_renamed needs_review completed reconciled].freeze

    def initialize(directory)
      @directory = Pathname.new(directory)
    end

    def open(asset, writable: false)
      path = @directory.join("relocation-#{asset.record_id}-#{asset.id}.jsonl")
      validate_directory!
      flags = (writable ? File::RDWR : File::RDONLY) | File::NOFOLLOW | File::NONBLOCK
      File.open(path, flags) do |file|
        lock_file!(file, path, writable)

        rows = read_rows(file)
        file.seek(0, IO::SEEK_END)
        yield file, rows
      end
    end

    def validate_rows!(rows, payload)
      events = rows.map { |row| row.fetch('event') }
      raise ArgumentError, 'Unexpected checkpoint events' unless valid_events?(events)

      prepared = rows.find { |row| row['event'] == 'prepared' }
      if prepared && prepared.except('event', 'at') != payload.as_json
        raise ArgumentError, 'Checkpoint differs from the fixed reviewed operation'
      end
      raise ArgumentError, 'Missing prepared evidence' if prepared.nil? && (events - ['needs_review']).any?
    end

    private

    def lock_file!(file, path, writable)
      validate_file!(file, path)
      lock = writable ? File::LOCK_EX : File::LOCK_SH
      raise ArgumentError, 'Checkpoint is busy' unless file.flock(lock | File::LOCK_NB)
    end

    def valid_events?(events)
      (events - EVENTS).empty? && events.count('prepared') <= 1 &&
        events.count('filesystem_renamed') <= 1 && events.count('completed') <= 1
    end

    def validate_directory!
      stat = File.lstat(@directory)
      valid = @directory.absolute? && @directory.cleanpath == @directory && @directory.realpath == @directory &&
              stat.directory? && stat.uid == Process.uid && stat.mode.nobits?(0o077)
      raise ArgumentError, 'Unsafe checkpoint directory' unless valid
    end

    def validate_file!(file, path)
      stat = file.stat
      valid = stat.file? && stat.uid == Process.uid && stat.mode.nobits?(0o077) && stat.nlink == 1 &&
              path.realpath == path && File.lstat(path).ino == stat.ino
      raise ArgumentError, 'Unsafe checkpoint file' unless valid
    end

    def read_rows(file)
      data = file.read(4_194_305) || ''
      complete = data.empty? || data.end_with?("\n")
      raise ArgumentError, 'Checkpoint too large or partially written' unless data.bytesize <= 4_194_304 && complete

      data.lines.map { |line| JSON.parse(line) }
    end
  end
end
