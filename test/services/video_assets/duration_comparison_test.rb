# frozen_string_literal: true

require 'test_helper'

class DurationComparisonTest < ActiveSupport::TestCase
  Copy = Struct.new(:duration_minutes, :broadcast_part_number, :technical_details)

  test 'only differences strictly smaller than ten percent of catalogue duration are concordant' do
    assert compare(100, copy(91))
    assert compare(100, copy(109))
    assert_not compare(100, copy(90))
    assert_not compare(100, copy(110))
  end

  test 'all measured copies must fit the interval' do
    assert compare(100, copy(95), copy(108))
    assert_not compare(100, copy(95), copy(120))
  end

  test 'missing catalogue values copies or measurements do not establish concordance' do
    assert_not compare(nil, copy(100))
    assert_not compare(0, copy(100))
    assert_not compare(100)
    assert_not compare(100, copy(nil))
    assert_not compare(100, copy(100), copy(nil))
  end

  test 'broadcast parts are added rather than individually compared with the whole work' do
    copies = [copy(40, 1), copy(60, 2)]
    assert VideoAssets::DurationComparison.new(catalogue: 100, copies: copies, expected_parts: 2).concordant?
    assert_not VideoAssets::DurationComparison.new(catalogue: 100, copies: copies.first(1), expected_parts: 2).concordant?
  end

  test 'whole versions and complete multipart versions must all agree' do
    copies = [copy(105), copy(40, 1), copy(60, 2)]
    assert VideoAssets::DurationComparison.new(catalogue: 100, copies: copies, expected_parts: 2).concordant?
    copies.first.duration_minutes = 115
    assert_not VideoAssets::DurationComparison.new(catalogue: 100, copies: copies, expected_parts: 2).concordant?
  end

  private

  def copy(minutes, part = nil)
    Copy.new(minutes, part, {})
  end

  def compare(catalogue, *copies)
    VideoAssets::DurationComparison.new(catalogue: catalogue, copies: copies).concordant?
  end
end
