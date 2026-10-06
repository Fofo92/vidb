# frozen_string_literal: true

require 'test_helper'
require 'minitest/mock'
require 'tempfile'

class BatchFileObservationTest < ActiveSupport::TestCase
  test 'changed snapshot size or date is rejected before probing' do
    Tempfile.create('batch') do |file|
      file.write('original')
      file.flush
      entry = { path: file.path, size: file.size, modified_at: File.mtime(file.path).iso8601 }
      observer = VideoAssets::BatchFileObservation.new
      assert_raises(ArgumentError) { observer.call(entry.merge(size: 999)) }
      assert_raises(ArgumentError) { observer.call(entry.merge(modified_at: 2.days.ago.iso8601)) }
    end
  end

  test 'change between observation and application is detected' do
    Tempfile.create('batch') do |file|
      file.write('original')
      file.flush
      entry = { path: file.path, size: file.size, modified_at: File.mtime(file.path).iso8601 }
      technical = CatalogEnrichment::TechnicalObservation.new
      CatalogEnrichment::TechnicalObservation.stub(:new, -> { technical }) do
        technical.stub(:call, { path: file.path }) do
          observer = VideoAssets::BatchFileObservation.new
          observed = observer.call(entry)
          assert_nil observer.verify!(observed)
          file.write('changed')
          file.flush
          assert_raises(ArgumentError) { observer.verify!(observed) }
        end
      end
    end
  end
end
