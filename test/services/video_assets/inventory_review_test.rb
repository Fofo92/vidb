require 'test_helper'

class InventoryReviewTest < ActiveSupport::TestCase
  Asset = Struct.new(:id, :last_known_path, :byte_size, :observed_at)

  setup do
    @asset = Asset.new(1, '/videos/Films/Jo.mkv', 123, Time.utc(2026, 1, 3))
    @entry = { path: @asset.last_known_path, size: 123, modified_at: '2026-01-01T00:00:00Z' }
  end

  def review(entries, assets = [@asset])
    VideoAssets::InventoryReview.new(snapshot: { entries: entries }, assets: assets)
  end

  test 'a missing path is reported but no absence is inferred without an inventory' do
    assert_equal 'absent', review([]).call.first[:status]
    assert_empty VideoAssets::InventoryReview.new(snapshot: nil, assets: [@asset]).call
  end

  test 'a new encoding at the same path is reported as changed' do
    assert_equal 'changed', review([@entry.merge(size: 456)]).call.first[:status]
    assert_equal 'changed', review([@entry.merge(modified_at: '2026-01-04T00:00:00Z')]).call.first[:status]
  end

  test 'matching copies need no review' do
    assert_empty review([@entry]).call
  end

  test 'old and vf suffixes are proposed first without treating them as proof' do
    paths = %w[Unrelated.mkv Jo_old.mkv Jo_vf.mkv]
    entries = paths.map { |name| @entry.merge(path: "/videos/Films/#{name}") }
    candidates = review(entries).call.first[:candidates].pluck(:path)
    assert_equal ['/videos/Films/Jo_old.mkv', '/videos/Films/Jo_vf.mkv', '/videos/Films/Unrelated.mkv'], candidates
  end

  test 'an old file can be proposed while the original path contains a new encoding' do
    entries = [@entry.merge(size: 456), @entry.merge(path: '/videos/Films/Jo_old.mkv')]
    row = review(entries).call.first
    assert_equal 'changed', row[:status]
    assert_equal ['/videos/Films/Jo_old.mkv'], row[:candidates].pluck(:path)
  end

  test 'another confirmed copy or another directory is never a rename candidate' do
    other = Asset.new(2, '/videos/Films/Jo_old.mkv', 123, @asset.observed_at)
    entries = [@entry.merge(path: other.last_known_path), @entry.merge(path: '/videos/Elsewhere/Jo_old.mkv')]
    assert_empty review(entries, [@asset, other]).candidates(@asset)
  end

  test 'a changed size or a newer timestamp prevents a rename suggestion' do
    entries = [@entry.merge(path: '/videos/Films/Jo_old.mkv', size: 789),
               @entry.merge(path: '/videos/Films/Jo_vf.mkv', modified_at: '2026-01-04T00:00:00Z')]
    assert_empty review(entries).candidates(@asset)
  end

  test 'missing measurements are explicit and do not suggest a rename' do
    @asset.byte_size = nil
    row = review([@entry]).call.first
    assert_equal 'unverified', row[:status]
    assert_empty row[:candidates]
  end
end
