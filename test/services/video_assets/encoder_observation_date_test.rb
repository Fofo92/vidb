# frozen_string_literal: true

require 'test_helper'
require 'tmpdir'

class EncoderObservationDateTest < ActiveSupport::TestCase
  Asset = Struct.new(:last_known_path, :byte_size, :observed_at, :technical_details)

  test 'canonical observation date permits checking a companion without legacy provenance date' do
    Dir.mktmpdir do |directory|
      path = File.join(directory, 'part.mkv')
      project = File.join(directory, 'part.json')
      File.write(path, 'video')
      File.write(project, JSON.generate(format: 'another-project'))
      copy_time = 3.days.ago.to_time
      project_time = 4.days.ago.to_time
      File.utime(copy_time, copy_time, path)
      File.utime(project_time, project_time, project)
      asset = Asset.new(path, 5, 2.days.ago, {})
      result = VideoAssets::EncoderLanguageEvidence.new(asset).call
      assert_equal 'unsupported_project', result[:status]
      asset.observed_at = 5.days.ago
      assert_equal 'copy_not_stable', VideoAssets::EncoderLanguageEvidence.new(asset).call[:status]
    end
  end
end
