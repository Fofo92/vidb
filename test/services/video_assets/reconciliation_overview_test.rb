# frozen_string_literal: true

require 'test_helper'
require 'tmpdir'

class ReconciliationOverviewTest < ActiveSupport::TestCase
  test 'excludes work files and counts candidates as remaining debt' do
    with_journal do |path|
      result = service(path).call
      assert_equal 2, result[:total]
      assert_equal 1, result[:confirmed]
      assert_equal 1, result[:remaining]
      assert_equal 50.0, result[:percent]
      assert_equal 1, result[:excluded]
      assert_equal({ 'candidate' => 1 }, result[:counts])
    end
  end

  test 'missing and malformed journals leave the homepage usable' do
    with_journal do |path|
      path.write('invalid JSON')
      assert_not service(path).call[:available]
      path.delete
      assert_not service(path).call[:available]
    end
  end

  test 'an empty inventory has no division by zero' do
    with_journal do |path|
      data = JSON.parse(path.read)
      data['entries'] = []
      path.write(JSON.generate(data))
      assert_equal 0.0, service(path).call[:percent]
      assert_equal 0, service(path).call[:remaining]
    end
  end

  private

  def service(path)
    VideoAssets::ReconciliationOverview.new(path: path, cache: ActiveSupport::Cache::MemoryStore.new)
  end

  def with_journal
    Dir.mktmpdir do |directory|
      path = Pathname.new(directory).join('current.json')
      path.write(JSON.generate(
                   format: VideoAssets::ReconciliationFollowup::FORMAT, version: 1,
                   inventory_at: '2026-10-09T00:00:00Z', absent_since_previous: [],
                   entries: [
                     { path: '/videos/a.mkv', followup_status: 'confirmed' },
                     { path: '/videos/b.mkv', followup_status: 'candidate' },
                     { path: '/videos/video_encoder_a_workspace/video.mkv', followup_status: 'candidate' }
                   ]
                 ))
      yield path
    end
  end
end
