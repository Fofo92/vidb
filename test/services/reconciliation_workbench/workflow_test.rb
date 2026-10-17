require 'test_helper'
require 'minitest/mock'
require 'tmpdir'

class ReconciliationWorkbenchWorkflowTest < ActiveSupport::TestCase
  setup do
    @language = LanguageVersion.create!(short_name: 'VF', long_name: 'Français')
    @record = Record.create!(french_title: 'Œuvre de test', original_title: '', record_kind: 'standalone_video',
                             language_version: @language)
  end

  def proposal(field: 'year', value: 2020)
    { 'record_id' => @record.id, 'field' => field, 'value' => value,
      'year_basis' => 'first_release', 'identity' => @record.attributes.slice('french_title', 'original_title'),
      'reason' => 'Identité vérifiée dans la source officielle', 'sources' => ['https://example.org/catalogue/film'] }
  end

  def import_proposals(*rows)
    ReconciliationWorkbench::Proposals.new.call('format' => 'vidb.sourced_metadata_proposals', 'version' => 1,
                                               'proposals' => rows)
  end

  def approve(item)
    rule = ReconciliationWorkbench::Rules.fetch(item.rule_key)
    ReconciliationRuleDecision.create!(rule_key: rule.key, rule_version: rule.version, decision: 'approved',
                                      case_fingerprints: rule.recurring ? [] : [item.fingerprint])
  end

  test 'no approval means no metadata change' do
    item = import_proposals(proposal).first
    assert_equal 'skipped', ReconciliationWorkbench::Executor.new.call(item)
    assert_nil @record.reload.year
    assert_equal 'pending', item.reload.status
  end

  test 'an approved family applies to later equivalent missing values' do
    first = import_proposals(proposal).first
    approve(first)
    other = Record.create!(french_title: 'Autre œuvre', original_title: '', record_kind: 'standalone_video',
                            language_version: @language)
    row = proposal.merge('record_id' => other.id, 'identity' => other.attributes.slice('french_title', 'original_title'))
    later = import_proposals(row).first
    assert later.permitted?
    assert_equal 'applied', ReconciliationWorkbench::Executor.new.call(later)
    assert_equal 2020, other.reload.year
    assert_nil @record.reload.year
  end

  test 'replacement approval is limited to the exact current propositions' do
    @record.update!(year: 2010)
    item = import_proposals(proposal).first
    assert_equal 'sourced_year_replace', item.rule_key
    approve(item)
    later = import_proposals(proposal(value: 2021)).first
    assert_not later.permitted?
    assert_equal 'skipped', ReconciliationWorkbench::Executor.new.call(later)
    assert_equal 2010, @record.reload.year
  end

  test 'metadata approval never approves a disk family' do
    item = import_proposals(proposal).first
    approve(item)
    disk = ReconciliationWorkbench::CaseStore.propose(rule: ReconciliationWorkbench::Rules::DISK, key: '/videos/test.mkv',
                                                      payload: { 'records' => {}, 'file_count' => 1 })
    assert_not disk.permitted?
  end

  test 'manual changes even reverted invalidate an old proposal' do
    item = import_proposals(proposal).first
    approve(item)
    @record.update!(abstract: 'Modification manuelle')
    @record.update!(abstract: nil)
    assert_equal 'blocked', ReconciliationWorkbench::Executor.new.call(item)
    assert_nil @record.reload.year
    assert_match 'modifiée depuis', item.reload.error
  end

  test 'independent sourced characteristics can follow known engine changes on the same record' do
    year, abstract = import_proposals(proposal, proposal(field: 'abstract', value: 'Résumé sourcé'))
    approve(year)
    approve(abstract)
    executor = ReconciliationWorkbench::Executor.new
    assert_equal 'applied', executor.call(year)
    assert_equal 'applied', executor.call(abstract)
    assert_equal 2020, @record.reload.year
    assert_equal 'Résumé sourcé', @record.abstract
    assert_equal 'external', @record.abstract_provenance['kind']
  end

  test 'SQL failure rolls back metadata and the completion receipt together' do
    item = import_proposals(proposal).first
    approve(item)
    ReconciliationRecordChange.stub(:create!, ->(**_args) { raise 'Failure while journalling' }) do
      assert_equal 'blocked', ReconciliationWorkbench::Executor.new.call(item)
    end
    assert_nil @record.reload.year
    assert_equal 0, ReconciliationRecordChange.where(reconciliation_case: item).count
    assert_equal 'applied', ReconciliationWorkbench::Executor.new.call(item)
    assert_equal 2020, @record.reload.year
    before = @record.attributes
    assert_equal 'skipped', ReconciliationWorkbench::Executor.new.call(item)
    assert_equal before, @record.reload.attributes
  end

  test 'revocation stops subsequent cases in an approved family' do
    item = import_proposals(proposal).first
    approve(item)
    ReconciliationRuleDecision.find_by!(rule_key: item.rule_key).update!(decision: 'deferred')
    assert_equal 'skipped', ReconciliationWorkbench::Executor.new.call(item)
    assert_nil @record.reload.year
  end

  test 'proposals with mismatching identity or non https sources are refused without partial writes' do
    assert_raises(ArgumentError) { import_proposals(proposal.merge('identity' => {})) }
    assert_raises(ArgumentError) { import_proposals(proposal.merge('sources' => ['javascript:alert(1)'])) }
    assert_equal 0, ReconciliationCase.count
  end

  test 'a version change does not inherit an approval' do
    item = import_proposals(proposal).first
    approve(item)
    item.update!(rule_version: item.rule_version + 1)
    assert_not item.permitted?
  end
end
