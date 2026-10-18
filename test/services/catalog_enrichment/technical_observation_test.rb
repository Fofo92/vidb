# frozen_string_literal: true

require 'test_helper'
require 'minitest/mock'
require 'tempfile'

class TechnicalObservationTest < ActiveSupport::TestCase
  test 'measures streams and storage without inventing a language' do
    Tempfile.create('copy') do |file|
      file.write('example')
      file.flush
      observation = CatalogEnrichment::TechnicalObservation.new
      calls = []
      command = lambda do |*arguments|
        calls << arguments
        if arguments.first == 'ffprobe'
          { 'format' => { 'duration' => '60.25', 'format_name' => 'mp4' },
            'streams' => [{ 'codec_type' => 'audio', 'tags' => { 'language' => 'und' } }] }
        else
          { 'filesystems' => [{ 'target' => '/videos', 'uuid' => 'test-volume' }] }
        end
      end
      observation.stub(:command, command) do
        result = observation.call(file.path)
        assert_equal 'und', result.dig(:technical_details, 'streams', 0, 'tags', 'language')
        assert_equal 'test-volume', result.dig(:technical_details, 'storage', 'uuid')
        assert_in_delta 60.25, result[:measured_duration_seconds]
        assert_equal 1, result[:duration_minutes]
        assert_equal 7, result[:byte_size]
        assert_equal 'mp4', result[:container]
        assert_equal %w[ffprobe findmnt], calls.map(&:first)
        assert_includes calls.first, '-show_format'
        assert_includes calls.first, '-show_streams'
      end
    end
  end

  test 'a file changed during the combined probe is rejected' do
    Tempfile.create('copy') do |file|
      file.write('before')
      file.flush
      command = lambda do |*arguments|
        if arguments.first == 'ffprobe'
          File.write(file.path, 'changed during probe')
          { 'format' => { 'duration' => '60', 'format_name' => 'mp4' }, 'streams' => [] }
        else
          { 'filesystems' => [{ 'target' => '/videos' }] }
        end
      end
      CatalogEnrichment::TechnicalObservation.new.stub(:command, command) do |observation|
        assert_raises(ArgumentError) { observation.call(file.path) }
      end
    end
  end

  test 'the combined probe still rejects an invalid duration' do
    Tempfile.create('copy') do |file|
      result = { 'format' => { 'duration' => 'NaN', 'format_name' => 'mp4' }, 'streams' => [] }
      CatalogEnrichment::TechnicalObservation.new.stub(:command, result) do |observation|
        assert_raises(ArgumentError) { observation.call(file.path) }
      end
    end
  end

  test 'non regular paths are rejected before invoking ffprobe' do
    observation = CatalogEnrichment::TechnicalObservation.new
    command = ->(*) { flunk 'No process should read a non regular path' }
    observation.stub(:command, command) do
      assert_raises(ArgumentError) { observation.call(Dir.tmpdir) }
    end
  end

  test 'a zero duration is rejected with the affected path' do
    Tempfile.create('copy') do |file|
      result = { 'format' => { 'duration' => '0', 'format_name' => 'mp4' }, 'streams' => [] }
      CatalogEnrichment::TechnicalObservation.new.stub(:command, result) do |observation|
        error = assert_raises(ArgumentError) { observation.call(file.path) }
        assert_includes error.message, file.path
      end
    end
  end
end
