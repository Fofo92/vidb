# frozen_string_literal: true

require 'open3'

module VideoAssets
  class ReconciliationVolumeGuard
    UUID = '3430606f-92bb-4da4-aaf2-36a3460bc298'

    def initialize(root:, uuid: UUID, command: Open3.method(:capture3))
      @root = root.to_s
      @uuid = uuid
      @command = command
    end

    def call
      result = @command.call('findmnt', '-rn', '-T', @root, '-o', 'TARGET,UUID')
      output = result.fetch(0)
      status = result.fetch(2)
      raise ArgumentError, 'Video volume unavailable; previous followup preserved' unless status.success?

      return if output.split == [@root, @uuid]

      raise ArgumentError, 'Unexpected video mount or UUID; previous followup preserved'
    end
  end
end
