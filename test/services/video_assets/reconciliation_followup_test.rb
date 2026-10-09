# frozen_string_literal: true

require 'test_helper'

class ReconciliationFollowupTest < ActiveSupport::TestCase
  Asset = Struct.new(:last_known_path, :byte_size, :observed_at)

  test 'candidates remain proposals and ambiguous entries require review' do
    result = follow(report([entry('/videos/a'), entry('/videos/b', candidates: [])]))
    assert_equal({ 'candidate' => 1, 'needs_review' => 1 }, result[:counts])
    assert_equal 2, result[:new_paths].size
  end

  test 'confirmed assets take precedence over title matching' do
    asset = Asset.new('/videos/a', 100, Time.utc(2026, 10, 8))
    result = follow(report([entry('/videos/a', candidates: [])]), assets: [asset])
    assert_equal 'confirmed', result[:entries].first[:followup_status]
  end

  test 'size or modification changes reopen confirmed copies' do
    asset = Asset.new('/videos/a', 99, Time.utc(2026, 10, 8))
    assert_equal 'confirmed_copy_changed', follow(report([entry('/videos/a')]), assets: [asset])[:entries].first[:followup_status]
    asset.byte_size = 100
    asset.observed_at = Time.utc(2026, 10, 1)
    assert_equal 'confirmed_copy_changed', follow(report([entry('/videos/a')]), assets: [asset])[:entries].first[:followup_status]
  end

  test 'reruns preserve first observation and do not invent new cases' do
    input = report([entry('/videos/a')])
    first = follow(input)
    second = follow(input, previous: first)
    assert_empty second[:new_paths]
    assert_equal first[:entries].first[:first_seen_at], second[:entries].first[:first_seen_at]
    assert_not second[:entries].first[:changed_since_previous]
  end

  test 'absence is a warning and never changes database states' do
    first = follow(report([entry('/videos/a')]))
    assert_no_difference 'VideoAsset.count' do
      result = follow(report([]), previous: first)
      assert_equal ['/videos/a'], result[:absent_since_previous]
    end
  end

  test 'older snapshots and changed scopes are refused' do
    first = follow(report([]))
    old = report([])
    old[:source_inventory][:generated_at] = '2026-10-01T00:00:00Z'
    assert_raises(ArgumentError) { follow(old, previous: first) }
    changed = report([])
    changed[:source_inventory][:roots] = ['/another']
    assert_raises(ArgumentError) { follow(changed, previous: first) }
  end

  private

  def follow(input, previous: nil, assets: [])
    VideoAssets::ReconciliationFollowup.new(report: input, previous: previous, assets: assets).call
  end

  def report(entries)
    { format: VideoAssets::ReconciliationReport::FORMAT, version: VideoAssets::ReconciliationReport::VERSION,
      source_inventory: { roots: ['/videos'], generated_at: '2026-10-09T00:00:00Z' }, observations: entries }
  end

  def entry(path, candidates: [{ record_id: 1 }])
    { path: path, size: 100, modified_at: '2026-10-07T00:00:00Z', status: 'exact', candidates: candidates }
  end
end
