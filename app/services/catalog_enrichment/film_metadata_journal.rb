# frozen_string_literal: true

require 'json'

module CatalogEnrichment
  class FilmMetadataJournal
    def initialize(directory:)
      @directory = Pathname.new(directory)
    end

    def rows(id)
      return [] unless @directory.exist? || @directory.symlink?

      validate_directory!
      return [] unless path(id).exist? || path(id).symlink?

      File.open(path(id), File::RDONLY | File::NOFOLLOW) do |file|
        validate_file!(file.stat)
        file.each_line.map { |line| JSON.parse(line) }
      end
    end

    def append(id, operation, event, details = {})
      prepare_directory!
      previous = rows(id)
      if previous.any? && previous.any? { |row| row['operation_id'] != operation || row['record_id'] != id }
        raise ArgumentError, 'Journal belongs to another operation'
      end

      flags = File::WRONLY | File::APPEND | File::NOFOLLOW
      flags |= File::CREAT | File::EXCL if previous.empty?
      payload = details.merge(record_id: id, operation_id: operation, event: event, at: Time.current.iso8601(6))
      write_event(id, flags, payload)
      File.open(@directory, File::RDONLY | File::NOFOLLOW, &:fsync)
    end

    def path(id)
      raise ArgumentError, 'Positive record id required' unless id.is_a?(Integer) && id.positive?

      @directory.join("record-#{id}.jsonl")
    end

    private

    def write_event(id, flags, payload)
      File.open(path(id), flags, 0o600) do |file|
        validate_file!(file.stat)
        file.write("#{JSON.generate(payload)}\n")
        file.flush
        file.fsync
      end
    end

    def prepare_directory!
      canonical = @directory.absolute? && @directory == @directory.cleanpath
      unless canonical && @directory.dirname.realpath == @directory.dirname
        raise ArgumentError, 'Canonical private journal directory required'
      end

      Dir.mkdir(@directory, 0o700) unless @directory.exist? || @directory.symlink?
      validate_directory!
    end

    def validate_directory!
      info = File.lstat(@directory)
      valid = info.directory? && info.uid == Process.uid && info.mode.nobits?(0o077) &&
              @directory.absolute? && @directory.realpath == @directory
      raise ArgumentError, 'Journal directory must be private, owned and without symlinks' unless valid
    end

    def validate_file!(info)
      valid = info.file? && info.uid == Process.uid && info.mode.nobits?(0o077) && info.size <= 2_097_152
      raise ArgumentError, 'Invalid private journal file' unless valid
    end
  end
end
