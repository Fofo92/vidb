# frozen_string_literal: true

require 'json'
require 'open3'

module CatalogEnrichment
  class TechnicalObservation
    def call(path)
      before = File.stat(path)
      measured = FileObservation.new.call(path)
      details = { 'streams' => streams(path), 'storage' => storage(path) }
      after = File.stat(path)
      raise ArgumentError, "File changed during observation: #{path}" unless identity(before) == identity(after)

      measured.merge(technical_details: details)
    end

    private

    def identity(stat)
      [stat.dev, stat.ino, stat.size, stat.mtime, stat.ctime]
    end

    def streams(path)
      probe = command('ffprobe', '-v', 'error', '-show_streams', '-of', 'json', path)
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
