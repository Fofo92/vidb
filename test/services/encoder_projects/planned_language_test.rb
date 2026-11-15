require 'test_helper'

class EncoderProjects::PlannedLanguageTest < ActiveSupport::TestCase
  def selected(hint: 'VMST', evidence: nil, submitted: {})
    proposal = { 'language_version' => 'VF' }
    proposal['series_candidate'] = { 'original_language_evidence' => evidence } if evidence
    EncoderProjects::PlannedLanguage.call(proposal: proposal, project: { 'language_hint' => hint },
                                          submitted: submitted)
  end

  test 'available VMST or VM takes priority over an earlier VF copy when French original is not established' do
    assert_equal 'VMST', selected
    assert_equal 'VM', selected(hint: 'VM')
    assert_equal 'VF', selected(hint: 'VF')
  end

  test 'a verified French original prevents treating qaa as proof of a foreign version' do
    evidence = { 'status' => 'french', 'language' => 'fr', 'provider' => 'tmdb' }
    assert_equal 'VF', selected(evidence: evidence)
    assert_equal 'VF', selected(hint: 'VM', evidence: evidence)
  end

  test 'conflicting or incomplete original language evidence does not discard available tracks' do
    assert_equal 'VMST', selected(evidence: { 'status' => 'french', 'language' => 'en', 'provider' => 'tmdb' })
    assert_equal 'VMST', selected(evidence: { 'status' => 'unknown' })
  end

  test 'the user reviewed form value is authoritative over the automatic proposal' do
    assert_equal 'VF', selected(submitted: { 'language_version' => 'VF' })
    evidence = { 'status' => 'french', 'language' => 'fr', 'provider' => 'tmdb' }
    assert_equal 'VMST', selected(evidence: evidence, submitted: { 'language_version' => 'VMST' })
  end

  test 'a missing or unknown source hint preserves the existing version as a fallback' do
    assert_equal 'VF', selected(hint: nil)
    assert_equal 'VF', selected(hint: 'IND')
  end

  test 'raw TMDB evidence is reused for a new series without another network request' do
    resolver = EncoderProjects::SeriesOriginalLanguage.new
    french = resolver.evidence_for({ 'id' => 10, 'name' => 'Série française', 'original_language' => 'fr' })
    foreign = resolver.evidence_for({ 'id' => 20, 'name' => 'Foreign Series', 'original_language' => 'en' })
    assert_equal 'VF', selected(evidence: french)
    assert_equal 'VMST', selected(evidence: foreign)
  end
end
