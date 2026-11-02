# frozen_string_literal: true

require 'test_helper'
require 'open3'

class BridgeManagementTest < ActiveSupport::TestCase
  test 'bridge management Python tests pass without production side effects' do
    output, status = Open3.capture2e('python3', '-m', 'unittest', 'discover', '-s',
                                     Rails.root.join('test/python').to_s, '-p', 'test_bridges.py')
    assert status.success?, output
  end
end
