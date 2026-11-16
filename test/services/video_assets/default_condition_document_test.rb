require 'test_helper'

class VideoAssets::DefaultConditionDocumentTest < ActiveSupport::TestCase
  def proposal(name, details = {})
    VideoAssets::DefaultConditionDocument.call("/videos/#{name}.mkv", details)
  end

  test 'unmarked copies are presumed complete and undamaged without claiming verification' do
    result = proposal('Film')
    assert_equal 'complete', result['integrality']
    assert_equal 'none', result['damage']
    assert_equal %w[integrality damage], result['presumed_fields']
    assert_equal 'copy_condition_convention_v1', result.fetch('evidence').sole['origin']
  end

  test 'a known defect is retained and only its unqualified independent axis receives a presumption' do
    damage = proposal('Film (dd)')
    assert_equal 'severe', damage['damage']
    assert_equal ['integrality'], damage['presumed_fields']
    incomplete = proposal('Film (i)')
    assert_equal 'incomplete', incomplete['integrality']
    assert_equal ['damage'], incomplete['presumed_fields']
    combined = proposal('Film (i) (d)')
    assert_equal 'incomplete', combined['integrality']
    assert_equal 'light', combined['damage']
    assert_not combined.key?('presumed_fields')
  end

  test 'beginning and end without duration are incomplete without any inferred duration' do
    { 'début' => 'beginning', 'fin' => 'end' }.each do |marker, part|
      result = proposal("Film (#{marker})")
      assert_equal 'incomplete', result['integrality']
      assert_equal part, result['retained_portion']
      assert_nil result['retained_duration_seconds']
      assert_equal false, result['needs_review']
    end
  end

  test 'manual qualifications and explicit uncertainty are never replaced by filenames or defaults' do
    [{ 'integrality' => 'unknown', 'damage' => 'unknown' },
     { 'integrality' => 'complete', 'damage' => 'none', 'evidence' => [{ 'origin' => 'manual' }] },
     { 'integrality' => 'incomplete', 'damage' => 'light', 'note' => 'Coupure signalée' }].each do |details|
      before = details.deep_dup
      assert_equal before, proposal('Film (dd)', details)
      assert_equal before, details
    end
  end

  test 'legacy gaps can be completed without erasing markers and previous provenance' do
    old = VideoAssets::LegacyConditionMarkers.call('/videos/Film (d).mkv')
    before = old.deep_dup
    result = proposal('Film (d)', old)
    assert_equal 'complete', result['integrality']
    assert_equal 'light', result['damage']
    assert_equal before.fetch('evidence').first, result.fetch('evidence').first
    assert_equal before, old
  end

  test 'ambiguous and unsupported markers stay outside automatic qualification' do
    ["Film (début 41)", "Film (début) (fin)", "Film (d - 23')", "Film (i - 41')"].each do |name|
      assert_nil proposal(name), name
    end
    assert_nil proposal('Film', { 'needs_review' => true })
    assert_nil VideoAssets::DefaultConditionDocument.call(nil)
  end

  test 'folder markers and Roman numerals never qualify the file and repeated calls are stable' do
    result = VideoAssets::DefaultConditionDocument.call('/videos/Série (i)/Film (I).mkv')
    assert_equal 'complete', result['integrality']
    assert_equal result, VideoAssets::DefaultConditionDocument.call('/videos/Série (i)/Film (I).mkv', result)
  end
end
