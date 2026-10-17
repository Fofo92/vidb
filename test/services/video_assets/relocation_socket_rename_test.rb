# frozen_string_literal: true

require 'test_helper'
require 'tmpdir'
require 'fileutils'

class RelocationSocketRenameTest < ActiveSupport::TestCase
  class Peer
    attr_reader :requests

    def initialize(uid: 0, &response)
      @uid = uid
      @response = response
      @requests = []
    end

    def getsockopt(*)
      [1, @uid, 1].pack('iii')
    end

    def puts(line)
      @requests << JSON.parse(line)
    end

    def gets(*)
      @response.call(@requests.last)
    end
  end

  setup do
    @directory = Dir.mktmpdir('vidb-socket-contract-', '/tmp')
    @source = File.join(@directory, 'old.mkv')
    @target = File.join(@directory, 'new.mkv')
    File.binwrite(@source, 'fixture')
    @identity = VideoAssets::RelocationFileIdentity.call(File.stat(@source))
    @plan = { ready: true, source: @source, target: @target, identity: @identity }
  end

  teardown do
    FileUtils.remove_entry(@directory)
  end

  test 'probe and rename send only the pinned operation and verify the resulting copy' do
    peer = Peer.new do |request|
      if request['op'] == 'probe'
        "{\"status\":\"ready\"}\n"
      else
        File.rename(@source, @target)
        "{\"status\":\"renamed\"}\n"
      end
    end
    client = client_for(peer)
    client.probe
    assert File.exist?(@source)
    client.call(**arguments)
    assert_equal %w[probe rename], peer.requests.map { |request| request['op'] }
    assert_equal @identity.stringify_keys, peer.requests.last['identity']
    assert_equal 'fixture', File.binread(@target)
    assert_equal @identity[:ino], File.stat(@target).ino
  end

  test 'another path or identity is refused without sending a request' do
    peer = Peer.new { raise 'must not send' }
    client = client_for(peer)
    assert_raises(ArgumentError) { client.call(**arguments.merge(target: "#{@target}.other")) }
    assert_raises(ArgumentError) { client.call(**arguments.merge(identity: @identity.merge(size: 0))) }
    assert_empty peer.requests
    assert File.exist?(@source)
  end

  test 'later mutation of the caller plan cannot change the pinned destination' do
    peer = Peer.new { raise 'must not send' }
    client = client_for(peer)
    @plan[:target] = "#{@target}.other"
    assert_raises(ArgumentError) { client.call(**arguments.merge(target: @plan[:target])) }
    assert_empty peer.requests
  end

  test 'a non-root peer is refused before sending any request' do
    peer = Peer.new(uid: 1000) { raise 'must not send' }
    assert_raises(ArgumentError) { client_for(peer).probe }
    assert_empty peer.requests
  end

  test 'worker failures never authorize a fallback rename' do
    peer = Peer.new { "{\"status\":\"failed\",\"error\":\"denied\"}\n" }
    assert_raises(ArgumentError) { client_for(peer).call(**arguments) }
    assert File.exist?(@source)
    assert_not File.exist?(@target)
  end

  test 'a false success cannot authorize the database update' do
    peer = Peer.new { "{\"status\":\"renamed\"}\n" }
    assert_raises(Errno::ENOENT) { client_for(peer).call(**arguments) }
    assert File.exist?(@source)
  end

  test 'malformed oversized and incomplete response frames are refused' do
    ["{\"status\":\"ready\"}", "#{'x' * 16_384}\n", "[]\n", "bad json\n"].each do |response|
      peer = Peer.new { response }
      assert_raises(ArgumentError, JSON::ParserError) { client_for(peer).probe }
    end
    assert File.exist?(@source)
  end

  test 'a preview that was not ready is refused' do
    assert_raises(ArgumentError) do
      VideoAssets::RelocationSocketRename.new(socket_path: '/tmp/not-opened.sock', plan: @plan.merge(ready: false))
    end
  end

  private

  def arguments
    { source: @source, target: @target, identity: @identity }
  end

  def client_for(peer)
    transport = Object.new
    transport.define_singleton_method(:open) { |_path, &block| block.call(peer) }
    VideoAssets::RelocationSocketRename.new(socket_path: '/tmp/not-opened.sock', plan: @plan, socket_class: transport)
  end
end
