# frozen_string_literal: true

require 'json'
require 'open3'

module CatalogEnrichment
  class TechnicalObservation
    def call(path)
      before = regular_file(path)
      probe = command('ffprobe', '-v', 'error', '-show_format', '-show_streams', '-of', 'json', path)
      measured = FileObservation.new.call(path, format: probe.fetch('format'))
      details = { 'streams' => streams(probe), 'storage' => storage(path) }
      after = File.stat(path)
      raise ArgumentError, "File changed during observation: #{path}" unless identity(before) == identity(after)

      measured.merge(technical_details: details)
    end

    private

    def regular_file(path)
      stat = File.stat(path)
      raise ArgumentError, "Not a regular file: #{path}" unless stat.file?

      stat
    end

    def identity(stat)
      [stat.dev, stat.ino, stat.size, stat.mtime, stat.ctime]
    end

    def streams(probe)
      probe.fetch('streams').map do |stream|
        stream.slice('index', 'codec_type', 'codec_name', 'channels', 'width', 'height', 'tags', 'disposition')
      end
    end

    def storage(path)
      command('findmnt', '--json', '--target', File.realpath(path),
              '--output', 'SOURCE,TARGET,FSTYPE,UUID,LABEL').fetch('filesystems').sole
    end

    def command(*arguments)
      output, error, status = Open3.capture3(*arguments)
      raise ArgumentError, "#{arguments.first} failed: #{error}" unless status.success?

      JSON.parse(output)
    end
  end
end
