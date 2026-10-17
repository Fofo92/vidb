# frozen_string_literal: true

require 'json'
require 'socket'
require 'timeout'

module VideoAssets
  # One pinned plan, one privileged worker; no command, fallback or arbitrary destination is sent.
  class RelocationSocketRename
    def initialize(socket_path:, plan:, socket_class: UNIXSocket)
      raise ArgumentError, 'A ready preview is required' unless plan[:ready] == true

      @socket_path = socket_path
      @plan = plan.deep_dup
      @socket_class = socket_class
    end

    def probe
      request('probe', @plan.fetch(:source), @plan.fetch(:target), @plan.fetch(:identity), 'ready')
    end

    def call(source:, target:, identity:)
      request('rename', source, target, identity, 'renamed')
      stat = File.lstat(target)
      valid = stat.file? && File.realpath(target) == target &&
              RelocationFileIdentity.call(stat).except(:ctime_ns) == identity.except(:ctime_ns) &&
              !File.exist?(source) && !File.symlink?(source)
      raise ArgumentError, 'Worker result requires inspection' unless valid
    end

    private

    def request(operation, source, target, identity, expected)
      unless [source, target, identity] == @plan.values_at(:source, :target, :identity)
        raise ArgumentError, 'Request differs from the pinned preview'
      end

      Timeout.timeout(30) do
        @socket_class.open(@socket_path) do |socket|
          check_peer!(socket)
          socket.puts(JSON.generate(op: operation, source: source, target: target, identity: identity))
          read_response!(socket, expected)
        end
      end
    end

    def check_peer!(socket)
      uid = socket.getsockopt(Socket::SOL_SOCKET, Socket::SO_PEERCRED).unpack('iii')[1]
      raise ArgumentError, 'Expected a root worker' unless uid.zero?
    end

    def read_response!(socket, expected)
      line = socket.gets(16_385).to_s
      raise ArgumentError, 'Invalid worker response framing' unless line.bytesize <= 16_384 && line.end_with?("\n")

      response = JSON.parse(line)
      return if response.is_a?(Hash) && response['status'] == expected

      raise ArgumentError, "Worker refused or failed: #{response.inspect}"
    end
  end
end
