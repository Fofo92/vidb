# frozen_string_literal: true

require 'test_helper'

class ReconciliationVolumeGuardTest < ActiveSupport::TestCase
  Status = Struct.new(:successful) do
    def success?
      successful
    end
  end

  test 'only the expected mount and UUID permit scanning' do
    command = lambda do |*args|
      assert_equal ['findmnt', '-rn', '-T', '/videos', '-o', 'TARGET,UUID'], args
      ["/videos #{VideoAssets::ReconciliationVolumeGuard::UUID}\n", '', Status.new(true)]
    end
    assert_nil VideoAssets::ReconciliationVolumeGuard.new(root: '/videos', command: command).call
  end

  test 'an unmounted directory on the root disk is refused' do
    command = ->(*) { ["/ another-volume\n", '', Status.new(true)] }
    assert_raises(ArgumentError) do
      VideoAssets::ReconciliationVolumeGuard.new(root: '/videos', command: command).call
    end
  end

  test 'mount lookup failure is refused' do
    command = ->(*) { ['', 'unavailable', Status.new(false)] }
    assert_raises(ArgumentError) do
      VideoAssets::ReconciliationVolumeGuard.new(root: '/videos', command: command).call
    end
  end
end
