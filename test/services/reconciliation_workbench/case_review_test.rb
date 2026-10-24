require 'test_helper'

class ReconciliationWorkbench::CaseReviewTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: 'case-review@example.com', password: 'password')
    language = LanguageVersion.create!(short_name: 'IND', long_name: 'Indéterminée')
    @record = Record.create!(french_title: 'Film à consolider', original_title: '', record_kind: 'standalone_video',
                             language_version: language)
    @first = proposal('year', 2020)
    @second = proposal('abstract', 'Résumé externe documenté')
  end

  def proposal(field, value)
    ReconciliationWorkbench::Proposals.new.call(
      'format' => 'vidb.sourced_metadata_proposals', 'version' => 1, 'proposals' => [
        { 'record_id' => @record.id, 'field' => field, 'value' => value, 'year_basis' => 'first_release',
          'identity' => @record.attributes.slice('french_title', 'original_title'),
          'reason' => 'Identité vérifiée dans les sources', 'sources' => ['https://example.org/oeuvre'] }
      ]).first
  end

  def review(items, decision: 'approved', token: nil, axis: 'metadata')
    token ||= ReconciliationWorkbench::ReviewScope.issue(items, axis: axis)
    ReconciliationWorkbench::CaseReview.new(user: @user, parameters: {
      axis: axis, ids: items.map(&:id), decision: decision, token: token, comment: 'Examen du lot' }).call
  end

  test 'approval covers selected proposals only and leaves records unchanged until execution' do
    before = @record.attributes
    result = review([@first])
    assert_equal 1, result[:count]
    assert_not_nil result[:run_id]
    assert @first.permitted?
    assert_not @second.permitted?
    assert_equal before, @record.reload.attributes
    assert_empty ReconciliationRuleDecision.all
    assert_equal 1, ReconciliationRun.where(mode: 'apply', status: 'queued').count
    assert_equal 'pending', @first.reload.status
  end

  test 'scoped approval can execute through the ordinary executor without a family approval' do
    review([@first])
    assert_equal 'applied', ReconciliationWorkbench::Executor.new.call(@first)
    assert_equal 2020, @record.reload.year
    assert_equal 'skipped', ReconciliationWorkbench::Executor.new.call(@second)
    assert_nil @record.abstract
  end

  test 'explicit deferral overrides an approved recurring family' do
    ReconciliationRuleDecision.create!(rule_key: @first.rule_key, rule_version: @first.rule_version, decision: 'approved')
    assert @first.permitted?
    review([@first], decision: 'deferred')
    assert_not @first.permitted?
    assert_equal 'skipped', ReconciliationWorkbench::Executor.new.call(@first)
    assert_nil @record.reload.year
    assert_equal 0, ReconciliationRun.count
  end

  test 'deferral and rejection persist across replanning of the same case key' do
    %w[deferred rejected].each do |decision|
      review([@first], decision: decision)
      next_item = proposal('year', decision == 'deferred' ? 2021 : 2022)
      assert_not next_item.permitted?
      assert_not @first.reload.active?
      @first = next_item
    end
  end

  test 'an old scoped approval never covers changed evidence even with a family approval' do
    ReconciliationRuleDecision.create!(rule_key: @first.rule_key, rule_version: 1, decision: 'approved')
    review([@first])
    changed = proposal('year', 2021)
    assert_not changed.permitted?
    assert_equal 'skipped', ReconciliationWorkbench::Executor.new.call(changed)
  end

  test 'stale expired or wrong axis tokens write no decision and queue no run' do
    token = ReconciliationWorkbench::ReviewScope.issue([@first], axis: 'metadata')
    assert_raises(ArgumentError) { review([@first], token: token, axis: 'disk') }
    travel 3.hours do
      assert_raises(ArgumentError) { review([@first], token: token) }
    end
    @first.update!(active: false)
    assert_raises(ArgumentError) { review([@first], token: token) }
    assert_equal 0, ReconciliationCaseReview.count
    assert_equal 0, ReconciliationRun.count
  end

  test 'a proposal not displayed on the signed page cannot be approved' do
    token = ReconciliationWorkbench::ReviewScope.issue([@first], axis: 'metadata')
    assert_raises(ArgumentError) { review([@first, @second], token: token) }
    assert_equal 0, ReconciliationCaseReview.count
    assert_equal 0, ReconciliationRun.count
  end

  test 'ambiguous copy preferences cannot bypass their required arbitration' do
    copy = ReconciliationWorkbench::CaseStore.propose(rule: ReconciliationWorkbench::Rules::PREFERENCE,
      key: 'copies-to-choose', payload: { 'records' => {}, 'comparison' => { 'eligible' => false } })
    assert_raises(ArgumentError) { review([copy], axis: 'disk') }
    assert_equal 0, ReconciliationCaseReview.count
    assert_equal 0, ReconciliationRun.count
  end

  test 'repeated submission is idempotent and decisions retain their history' do
    token = ReconciliationWorkbench::ReviewScope.issue([@first], axis: 'metadata')
    first = review([@first], token: token)
    second = review([@first], token: token)
    assert_equal 1, first[:count]
    assert_equal 0, second[:count]
    assert_nil second[:run_id]
    assert_equal 1, ReconciliationRun.count
    review([@first], decision: 'deferred', token: token)
    receipt = ReconciliationCaseReview.for(@first).sole
    assert_equal 'deferred', receipt.decision
    assert_equal 'approved', receipt.history.sole['decision']
    assert_not @first.permitted?
  end

  test 'record edits after approval still block the normal executor' do
    review([@first])
    @record.update!(abstract: 'Texte manuel conservé')
    assert_equal 'blocked', ReconciliationWorkbench::Executor.new.call(@first)
    assert_nil @record.reload.year
    assert_equal 'Texte manuel conservé', @record.abstract
  end

  test 'approval does not grant permission to the other axis or to later cases' do
    review([@first])
    disk = ReconciliationWorkbench::CaseStore.propose(rule: ReconciliationWorkbench::Rules::DISK,
      key: '/videos/a.mkv', payload: { 'records' => {}, 'file_count' => 1 })
    assert_not disk.permitted?
    other = proposal('language_version_id', @record.language_version_id)
    assert_not other.permitted?
  end

  test 'case-level approvals appear in the application progress without a family decision' do
    review([@first])
    progress = ReconciliationWorkbench::ApplicationProgress.new.call.find { |row| row[:rule].key == @first.rule_key }
    assert_equal 1, progress[:counts]['pending']
    assert_not_nil progress[:approved_at]
  end
end
