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
      file_observer = CatalogEnrichment::FileObservation.new
      measured = { path: file.path, byte_size: 7, measured_duration_seconds: 60,
                   duration_minutes: 1, container: 'mp4', observed_at: Time.current }
      command = lambda do |*arguments|
        if arguments.first == 'ffprobe'
          { 'streams' => [{ 'codec_type' => 'audio', 'tags' => { 'language' => 'und' } }] }
        else
          { 'filesystems' => [{ 'target' => '/videos', 'uuid' => 'test-volume' }] }
        end
      end
      CatalogEnrichment::FileObservation.stub(:new, -> { file_observer }) do
        file_observer.stub(:call, measured) do
          observation.stub(:command, command) do
            result = observation.call(file.path)
            assert_equal 'und', result.dig(:technical_details, 'streams', 0, 'tags', 'language')
            assert_equal 'test-volume', result.dig(:technical_details, 'storage', 'uuid')
          end
        end
      end
    end
  end
end
