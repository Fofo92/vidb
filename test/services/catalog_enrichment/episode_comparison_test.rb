# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../../../app/services/catalog_enrichment/episode_comparison'

class EpisodeComparisonTest < Minitest::Test
  def setup
    @evidence = {
      'format' => 'vidb.external_episode_evidence', 'version' => 1,
      'target_record_id' => 3060, 'series_title' => 'Europe',
      'episodes' => [{ 'number' => 1, 'title' => 'Premier' }, { 'number' => 5, 'title' => 'Vivant' }]
    }
  end

  def test_agreeing_title_and_number_remain_unaccepted
    result = compare('E01 - Premier')
    assert_equal 'title_and_number_agree', result[:status]
    assert_equal false, result[:accepted]
  end

  def test_conflict_keeps_both_numbers
    result = compare('E01 - Vivant')
    assert_equal 'title_number_conflict', result[:status]
    assert_equal 1, result[:source_by_number]['number']
    assert_equal 5, result[:source_by_title].first['number']
  end

  def test_number_alone_does_not_identify_content
    assert_equal 'number_only_unverified', compare('E05')[:status]
  end

  def test_unknown_title
    assert_equal 'title_unmatched', compare('E01 - Autre')[:status]
  end

  def test_ambiguous_titles
    @evidence['episodes'].last['title'] = 'Premier'
    assert_equal 'title_ambiguous', compare('E01 - Premier')[:status]
  end

  def test_duplicate_numbers_are_rejected
    @evidence['episodes'].last['number'] = 1
    assert_raises(ArgumentError) { compare('E01') }
  end

  def test_other_records_are_excluded
    report = reconciliation('E01')
    report['observations'].first['container_candidates'].first['record_id'] = 77
    assert_empty service(report).call[:observations]
  end

  def test_wrong_root_title_is_excluded
    report = reconciliation('E01')
    report['observations'].first['container_candidates'].first['french_title'] = 'Autre'
    assert_empty service(report).call[:observations]
  end

  private

  def compare(stem)
    service(reconciliation(stem)).call[:observations].first
  end

  def service(report)
    CatalogEnrichment::EpisodeComparison.new(reconciliation: report, evidence: @evidence)
  end

  def reconciliation(stem)
    {
      'format' => 'vidb.video_asset_reconciliation', 'source_inventory' => { 'generated_at' => '2026-10-04' },
      'observations' => [{ 'stem' => stem, 'path' => "/videos/#{stem}.mkv",
                           'container_candidates' => [{ 'record_id' => 3060, 'french_title' => 'Europe' }] }]
    }
  end
end
