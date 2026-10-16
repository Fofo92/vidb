# frozen_string_literal: true

require 'json'
require 'time'

module VideoAssets
  class RelocationJournal
    def initialize(directory)
      @directory = Pathname.new(directory)
    end

    def open(asset, &block)
      prepare_directory!
      path = @directory.join("relocation-#{asset.record_id}-#{asset.id}.jsonl")
      flags = File::WRONLY | File::CREAT | File::EXCL | File::NOFOLLOW
      File.open(path, flags, 0o600) do |file|
        File.open(@directory, File::RDONLY | File::NOFOLLOW, &:fsync)
        block.call(file)
      end
    end

    def self.append(file, event, details = {})
      file.write("#{JSON.generate(details.merge(event: event, at: Time.now.utc.iso8601(6)))}\n")
      file.flush
      file.fsync
    end

    def self.failure(file, error)
      append(file, 'needs_review', error_class: error.class.name, error_message: error.message)
    rescue StandardError
      nil # Keep the original exception even if the final diagnostic cannot be written.
    end

    private

    def prepare_directory!
      unless @directory.absolute? && @directory == @directory.cleanpath
        raise ArgumentError, 'A canonical absolute journal directory is required'
      end

      create_directory!
      validate_directory!
    end

    def create_directory!
      return if @directory.exist? || @directory.symlink?
      unless @directory.dirname.realpath == @directory.dirname
        raise ArgumentError,
              'Journal parent must not contain symlinks'
      end

      Dir.mkdir(@directory, 0o700)
      File.open(@directory.dirname, File::RDONLY | File::NOFOLLOW, &:fsync)
    end

    def validate_directory!
      stat = File.lstat(@directory)
      valid = stat.directory? && stat.uid == Process.uid && stat.mode.nobits?(0o077) &&
              @directory.realpath == @directory
      raise ArgumentError, 'Journal directory must be private, owned and free of symlinks' unless valid
    end
  end
end
