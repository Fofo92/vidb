require "open3"

module Tv
  class KaffeineCommandRunner
    class CommandError < StandardError; end

    def initialize(command_runner: Open3.method(:capture3))
      @command_runner = command_runner
    end

    def call(command)
      stdout, stderr, status = @command_runner.call(*command)
      raise CommandError, error_message(stderr, status) unless status.success?

      stdout
    end

    private

    def error_message(stderr, status)
      message = stderr.strip
      return message unless message.empty?

      "busctl exited with status #{status.exitstatus.inspect}"
    end
  end
end
