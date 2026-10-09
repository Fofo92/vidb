# frozen_string_literal: true

require 'test_helper'

class BlockageSummaryTest < ActiveSupport::TestCase
  test 'seasons of the same series form one group with all paths and examples' do
    entries = [entry('/videos/Series/Saison 01/a.mkv'), entry('/videos/Series/Saison 02/b.mkv')]
    result = summarize(entries)
    assert_equal 2, result[:total_files]
    assert_equal 1, result[:groups].size
    assert_equal '/videos/Series', result[:groups].first[:directory]
    assert_equal 2, result[:groups].first[:paths].size
  end

  test 'workspace and trash are excluded even when a title candidate exists' do
    entries = [entry('/videos/.Trash-1000/files/a.mkv'),
               entry('/videos/Series/video_encoder_a_workspace/video.mkv')]
    assert_equal({ 'excluded_trash' => 1, 'excluded_workspace' => 1 }, summarize(entries)[:counts])
  end

  test 'confirmed copies do not reappear as title conflicts' do
    item = entry('/videos/a.mkv').merge(followup_status: 'confirmed', status: 'episode_title_conflict')
    assert_equal({ 'confirmed' => 1 }, summarize([item])[:counts])
  end

  test 'missing hierarchy differs from incorrect parent placement' do
    item = entry('/videos/a.mkv').merge(reason: 'container_ineligible', followup_status: 'needs_review')
    item[:container_candidates] = [{ record_id: 3, non_root: false, has_children: false }]
    assert_equal 'missing_hierarchy', VideoAssets::BlockageCategory.call(item)
    item[:container_candidates].first[:non_root] = true
    assert_equal 'parent_placement', VideoAssets::BlockageCategory.call(item)
    item[:container_candidates] << { record_id: 4 }
    assert_equal 'ambiguous_identification', VideoAssets::BlockageCategory.call(item)
  end

  test 'unknown reasons stay visible and absence remains a separate warning' do
    item = entry('/videos/a.mkv').merge(reason: 'future_reason', status: 'future_status',
                                      followup_status: 'needs_review')
    result = summarize([item])
    assert_equal({ 'other_review' => 1 }, result[:counts])
    assert_equal({ 'future_reason' => 1 }, result[:groups].first[:reasons])
    assert_equal ['/videos/absent.mkv'], result[:absent_since_previous]
  end

  test 'rejects unsupported formats without database writes' do
    assert_raises(ArgumentError) { VideoAssets::BlockageSummary.new(followup: {}).call }
    assert_no_difference 'VideoAsset.count' do
      summarize([entry('/videos/a.mkv')])
    end
  end

  private

  def entry(path)
    { path: path, followup_status: 'candidate', status: 'exact', candidates: [{ record_id: 1 }] }
  end

  def summarize(entries)
    VideoAssets::BlockageSummary.new(followup: {
      format: VideoAssets::ReconciliationFollowup::FORMAT, version: 1,
      inventory_at: '2026-10-09T00:00:00Z', entries: entries,
      absent_since_previous: ['/videos/absent.mkv']
    }).call
  end
end
