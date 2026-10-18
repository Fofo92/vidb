require 'test_helper'

class ReconciliationWorkbenchSeasonTitlePlanTest < ActiveSupport::TestCase
  setup do
    @language = LanguageVersion.create!(short_name: 'VF', long_name: 'Français')
  end

  def created_season(title, name = 'Une série', preexisting: false)
    root = Record.create!(french_title: name, record_kind: 'series', language_version: @language)
    season = root.children.create!(french_title: title, rank: 3, record_kind: 'season', language_version: @language)
    rule = ReconciliationWorkbench::Rules::SOURCED_STRUCTURE
    item = ReconciliationWorkbench::CaseStore.propose(rule: rule, key: "root:#{root.id}",
      payload: { 'record_id' => root.id, 'operations' => [{ 'season_id' => preexisting ? season.id : nil }] })
    item.update!(status: 'applied', active: false, result: { 'episodes' => [{ 'season_id' => season.id }] })
    season
  end

  def approve(items)
    rule = ReconciliationWorkbench::Rules::SEASON_TITLES
    ReconciliationRuleDecision.create!(rule_key: rule.key, rule_version: rule.version,
      decision: 'approved', case_fingerprints: items.map(&:fingerprint))
  end

  test 'one family covers several series using historical creation receipts without changing disk or other metadata' do
    seasons = [created_season('Saison 03', 'Première série'), created_season('Saison 03', 'Deuxième série')]
    seasons.first.update!(year: 1991)
    before = seasons.map { |season| season.attributes.except('french_title', 'updated_at') }
    items = ReconciliationWorkbench::SeasonTitlePlan.new.call
    assert_equal 2, items.size
    assert items.none?(&:permitted?)
    approve(items)
    executor = ReconciliationWorkbench::Executor.new
    items.each { |item| assert_equal 'applied', executor.call(item) }
    assert_equal ['Saison 3', 'Saison 3'], seasons.map { |season| season.reload.french_title }
    assert_equal before, seasons.map { |season| season.attributes.except('french_title', 'updated_at') }
    assert_equal 0, VideoAsset.count
    assert_empty ReconciliationWorkbench::SeasonTitlePlan.new.call
    assert_equal 'skipped', executor.call(items.first)
  end

  test 'existing seasons and manually chosen titles are excluded even with an applied structure case' do
    created_season('Saison 03', preexisting: true)
    created_season('Troisième saison')
    created_season('Saison 3')
    assert_empty ReconciliationWorkbench::SeasonTitlePlan.new.call
  end

  test 'manual changes after approval block application even after restoring the original title' do
    season = created_season('Saison 03')
    item = ReconciliationWorkbench::SeasonTitlePlan.new.call.sole
    approve([item])
    season.update!(french_title: 'Ma saison')
    season.update!(french_title: 'Saison 03')
    assert_equal 'blocked', ReconciliationWorkbench::Executor.new.call(item)
    assert_equal 'Saison 03', season.reload.french_title
    assert_match 'modifiée depuis la proposition', item.reload.error
    assert_equal item.id, ReconciliationWorkbench::SeasonTitlePlan.new.call.sole.id
  end

  test 'approval of structure alone never approves the correction of generated titles' do
    created_season('Saison 03')
    rule = ReconciliationWorkbench::Rules::SOURCED_STRUCTURE
    ReconciliationRuleDecision.create!(rule_key: rule.key, rule_version: rule.version,
      decision: 'approved', case_fingerprints: ReconciliationCase.pluck(:fingerprint))
    item = ReconciliationWorkbench::SeasonTitlePlan.new.call.sole
    assert_not item.permitted?
    assert_equal 'skipped', ReconciliationWorkbench::Executor.new.call(item)
  end
end
