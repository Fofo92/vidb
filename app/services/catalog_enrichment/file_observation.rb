# frozen_string_literal: true

require 'json'
require 'open3'

module CatalogEnrichment
  class FileObservation
    def call(path, format: nil)
      before = File.stat(path)
      raise ArgumentError, "Not a regular file: #{path}" unless before.file?

      measured = format ? measurement(format, path) : probe(path)
      after = File.stat(path)
      raise ArgumentError, "File changed during observation: #{path}" unless identity(before) == identity(after)

      measured.merge(path: path, byte_size: after.size, observed_at: Time.current)
    end

    private

    def identity(stat)
      [stat.dev, stat.ino, stat.size, stat.mtime, stat.ctime]
    end

    def probe(path)
      output, error, status = Open3.capture3(
        'ffprobe', '-v', 'error', '-show_entries', 'format=duration,format_name', '-of', 'json', path
      )
      raise ArgumentError, "ffprobe failed for #{path}: #{error}" unless status.success?

      measurement(JSON.parse(output).fetch('format'), path)
    end

    def measurement(format, path)
      seconds = Float(format.fetch('duration'))
      raise ArgumentError, "Invalid duration: #{path}" unless seconds.finite? && seconds.positive?

      { duration_minutes: [(seconds / 60).round, 1].max, measured_duration_seconds: seconds,
        container: format.fetch('format_name') }
    end
  end
end
