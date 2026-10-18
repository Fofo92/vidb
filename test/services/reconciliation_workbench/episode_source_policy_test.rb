require 'test_helper'

class ReconciliationWorkbenchEpisodeSourcePolicyTest < ActiveSupport::TestCase
  def reference(url, name = 'La découverte', number = 1)
    { 'name' => name, 'season' => 3, 'number' => number, 'url' => url }
  end

  def row(*references)
    { 'observed_title' => 'La découverte', 'local_season' => 3, 'local_episode' => 1,
      'reference_same_number' => references }
  end

  test 'French Wikipedia wins regardless of source order or provider labels' do
    french = reference('https://fr.wikipedia.org/wiki/Saison_3')
    english = reference('https://en.wikipedia.org/wiki/Episodes')
    guide = reference('https://example.org/episodes/1').merge('provider' => 'Wikipédia en français')
    [row(guide, english, french), row(french, english, guide)].each do |entry|
      assert_equal [french], ReconciliationWorkbench::SeriesEvidence.references(entry)
    end
  end

  test 'other Wikipedia editions are preferred when French Wikipedia is absent' do
    english = reference('https://en.wikipedia.org/wiki/Episodes')
    guide = reference('https://example.org/episodes/1')
    assert_equal [english], ReconciliationWorkbench::SeriesEvidence.references(row(guide, english))
  end

  test 'other sources remain usable for episodes with no supplied Wikipedia reference' do
    guide = reference('https://example.org/episodes/1')
    assert_equal [guide], ReconciliationWorkbench::SeriesEvidence.references(row(guide))
    assert_empty ReconciliationWorkbench::SeriesEvidence.references(row)
  end

  test 'a Wikipedia title contradiction cannot be bypassed through another matching guide' do
    french = reference('https://fr.wikipedia.org/wiki/Saison_3', 'Un autre titre')
    guide = reference('https://example.org/episodes/1')
    assert_empty ReconciliationWorkbench::SeriesEvidence.references(row(guide, french))
  end

  test 'a Wikipedia numbering difference blocks fallback without renumbering the episode' do
    french = reference('https://fr.wikipedia.org/wiki/Saison_3', 'La découverte', 2)
    guide = reference('https://example.org/episodes/1')
    entry = row(guide).merge('reference_other_numbers' => [french])
    assert_empty ReconciliationWorkbench::SeriesEvidence.references(entry)
    assert_equal 1, entry['local_episode']
  end

  test 'a generic Wikipedia title is held instead of overriding the title with another guide' do
    french = reference('https://fr.wikipedia.org/wiki/Saison_3', 'Episode 1')
    assert_empty ReconciliationWorkbench::SeriesEvidence.references(row(reference('https://example.org/1'), french))
  end

  test 'mobile Wikipedia is recognized but host suffix spoofs are not' do
    policy = ReconciliationWorkbench::EpisodeSourcePolicy
    assert_equal 0, policy.priority('https://fr.m.wikipedia.org/wiki/Saison_3')
    assert_equal 1, policy.priority('https://en.m.wikipedia.org/wiki/Episodes')
    assert_equal 2, policy.priority('https://fr.wikipedia.org.example.net/wiki/Episodes')
    assert_equal 2, policy.priority('https://example.org/fr.wikipedia.org')
    assert_raises(ArgumentError) { policy.priority('https://fr.wikipedia.org@example.org/wiki/Episodes') }
    assert_raises(ArgumentError) { policy.priority('http://fr.wikipedia.org/wiki/Episodes') }
  end

  test 'the new policy requires a new approval and keeps old cases immutable' do
    rule = ReconciliationWorkbench::Rules::SOURCED_STRUCTURE
    old = ReconciliationCase.create!(rule_key: rule.key, rule_version: 1, axis: 'metadata', case_key: 'series:old',
      fingerprint: 'a' * 64, payload: { 'operations' => [{ 'kind' => 'create_episode' }] })
    ReconciliationRuleDecision.create!(rule_key: rule.key, rule_version: 1, decision: 'approved',
      case_fingerprints: [old.fingerprint])
    assert_equal 2, rule.version
    assert_not old.permitted?
    assert_equal 1, old.reload.rule_version
    assert_equal [{ 'kind' => 'create_episode' }], old.payload['operations']
  end

  test 'canonical spelling never turns an original or contradictory title into a French title' do
    policy = ReconciliationWorkbench::EpisodeSourcePolicy
    assert_equal 'La découverte', policy.french_title([reference('https://en.wikipedia.org/wiki/Episodes', 'Discovery')], 'La découverte')
    assert_equal 'La découverte', policy.french_title([reference('https://fr.wikipedia.org/wiki/Episodes', 'Autre titre')], 'La découverte')
  end
end
