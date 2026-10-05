# frozen_string_literal: true

require 'test_helper'
require 'minitest/mock'
require 'tempfile'

class FileObservationTest < ActiveSupport::TestCase
  test 'retains measured seconds and rounds only the existing minutes column' do
    Tempfile.create(['observation', '.m4v']) do |file|
      file.write('sample')
      file.flush
      result = with_probe { CatalogEnrichment::FileObservation.new.call(file.path) }
      assert_in_delta 3202.56, result[:measured_duration_seconds]
      assert_equal 53, result[:duration_minutes]
      assert_equal 6, result[:byte_size]
    end
  end

  test 'missing file is rejected' do
    assert_raises(Errno::ENOENT) { CatalogEnrichment::FileObservation.new.call('/missing/vidb-test-file.m4v') }
  end

  test 'a file changing during measurement is rejected' do
    Tempfile.create(['observation', '.m4v']) do |file|
      callback = ->(*_args) { File.write(file.path, 'changed'); probe_output }
      Open3.stub(:capture3, callback) do
        assert_raises(ArgumentError) { CatalogEnrichment::FileObservation.new.call(file.path) }
      end
    end
  end

  private

  def with_probe(&block)
    Open3.stub(:capture3, probe_output, &block)
  end

  def probe_output
    status = Minitest::Mock.new
    status.expect(:success?, true)
    ['{"format":{"duration":"3202.56","format_name":"mov,mp4"}}', '', status]
  end
end
