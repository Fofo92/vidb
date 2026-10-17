require 'test_helper'

class ReconciliationWorkbenchControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(email: 'workbench@example.com', password: 'password')
    sign_in @user
    language = LanguageVersion.create!(short_name: 'VF', long_name: 'Français')
    @record = Record.create!(french_title: 'Œuvre documentée', record_kind: 'standalone_video', language_version: language)
    @rule = ReconciliationWorkbench::Rules.fetch('sourced_year_replace')
    @item = ReconciliationWorkbench::CaseStore.propose(rule: @rule, key: "record:#{@record.id}:year",
      payload: { 'record_id' => @record.id, 'title' => @record.french_title, 'field' => 'year',
        'before' => 2018, 'value' => 2019, 'reason' => 'Première diffusion',
        'sources' => ['https://www.arte.tv/fr/'], 'records' => {}, 'file_count' => 0 })
  end

  test 'both axes have distinct navigation and proposals' do
    get reconciliation_workbench_path
    assert_response :success
    assert_select 'a', text: '1 · Caractéristiques des œuvres'
    assert_select 'a', text: '2 · Liens avec le disque'
    assert_select 'h3', text: 'Arbitrer : année de référence'
    get reconciliation_workbench_path(axis: 'disk')
    assert_response :success
    assert_select 'h3', text: 'Rattacher une copie stable à une œuvre identifiée'
    assert_select 'h3', text: 'Arbitrer : année de référence', count: 0
  end

  test 'family displays before after and sources before one scoped decision' do
    get reconciliation_workbench_family_path(@rule.key)
    assert_response :success
    assert_select 'a[href="https://www.arte.tv/fr/"]'
    assert_select 'input[name="scope_digest"]'
    assert_select 'button[value="approved"]'
    post decision_reconciliation_workbench_family_path(@rule.key), params: decision_params
    assert_redirected_to reconciliation_workbench_path(axis: 'metadata')
    decision = ReconciliationRuleDecision.find_by!(rule_key: @rule.key)
    assert_equal [@item.fingerprint], decision.case_fingerprints
    assert_equal @user, decision.user
    assert_equal 1, ReconciliationRun.where(mode: 'apply', status: 'queued').count
    assert_not ReconciliationRuleDecision.exists?(rule_key: ReconciliationWorkbench::Rules::DISK.key)
    assert_equal 'pending', @item.reload.status
  end

  test 'a stale family form cannot approve unseen proposals' do
    post decision_reconciliation_workbench_family_path(@rule.key),
      params: decision_params.merge(scope_digest: 'old')
    assert_redirected_to reconciliation_workbench_family_path(@rule.key)
    assert_not ReconciliationRuleDecision.exists?(rule_key: @rule.key)
    assert_equal 0, ReconciliationRun.count
  end

  test 'deferring an approved rule prevents later application and does not enqueue work' do
    ReconciliationRuleDecision.create!(rule_key: @rule.key, rule_version: 1, decision: 'approved')
    post decision_reconciliation_workbench_family_path(@rule.key),
      params: decision_params.merge(decision: 'deferred')
    assert_equal 'deferred', ReconciliationRuleDecision.find_by!(rule_key: @rule.key).decision
    assert_not @item.permitted?
    assert_equal 0, ReconciliationRun.count
  end

  test 'stop requests preserve the current operation boundary' do
    run = ReconciliationRun.create!(mode: 'apply', status: 'running')
    post stop_reconciliation_workbench_path, params: { run_id: run.id }
    assert run.reload.stop_requested?
    assert_equal 'running', run.status
    get status_reconciliation_workbench_path
    assert_response :success
    assert_select 'turbo-frame#workbench_status'
  end

  test 'one family decision covers proposals beyond the first displayed page' do
    items = (1..31).map do |number|
      ReconciliationWorkbench::CaseStore.propose(rule: @rule, key: "extra:#{number}",
        payload: @item.payload.merge('title' => "Autre proposition #{number}"))
    end
    fingerprints = [@item, *items].map(&:fingerprint).sort
    get reconciliation_workbench_family_path(@rule.key)
    assert_select 'article', count: 30
    post decision_reconciliation_workbench_family_path(@rule.key), params: decision_params.merge(
      scope_digest: ReconciliationWorkbench::Snapshot.digest(fingerprints))
    assert_equal fingerprints, ReconciliationRuleDecision.find_by!(rule_key: @rule.key).case_fingerprints
  end

  test 'invalid proposal JSON is reported without queuing or changing records' do
    post proposals_reconciliation_workbench_path, params: { proposals: '{broken' }
    assert_redirected_to reconciliation_workbench_path(axis: 'metadata')
    assert_equal 1, ReconciliationCase.count
    assert_equal 0, ReconciliationRun.count
  end

  test 'copy comparisons show the existing paths and a provisional preferred copy' do
    rule = ReconciliationWorkbench::Rules::PREFERENCE
    samples = [1, 2].map do |id|
      { 'asset_id' => id, 'path' => "/videos/copy-#{id}.mkv", 'modified_at' => '2026-10-01T00:00:00Z',
        'measurement' => { 'byte_size' => 1000 } }
    end
    ReconciliationWorkbench::CaseStore.propose(rule: rule, key: "record:#{@record.id}", payload: {
      'record_id' => @record.id, 'title' => @record.french_title, 'samples' => samples,
      'comparison' => { 'eligible' => true, 'preferred_asset_id' => 2, 'reason' => 'Plus de pistes utiles' } })
    get reconciliation_workbench_family_path(rule.key)
    assert_response :success
    assert_select 'table[data-copy-comparison] tbody tr', count: 2
    assert_select 'input[type=radio][value="2"][checked][form="copy-arbitration"]', count: 1
    assert_select 'form#copy-arbitration', count: 1
    assert_select 'td', text: /copy-1\.mkv/
    assert_includes response.body, 'Qualité visuelle non évaluée'
  end

  test 'grouped copy choices submit through the separate form and authorize only those cases' do
    rule = ReconciliationWorkbench::Rules::PREFERENCE
    copy = ReconciliationWorkbench::CaseStore.propose(rule: rule, key: "record:#{@record.id}", payload: {
      'record_id' => @record.id, 'title' => @record.french_title,
      'samples' => [{ 'asset_id' => 10 }, { 'asset_id' => 'candidate' }],
      'records' => {}, 'comparison' => { 'eligible' => false, 'reason' => 'Langue à vérifier' } })
    post arbitrate_reconciliation_workbench_family_path(rule.key), params: {
      scope_digest: ReconciliationWorkbench::Snapshot.digest([copy.fingerprint]),
      choices: { copy.id.to_s => 'candidate' }, comment: 'Copie choisie après examen' }
    assert_redirected_to reconciliation_workbench_path(axis: 'disk')
    receipt = ReconciliationCase.current.find_by!(rule_key: ReconciliationWorkbench::Rules::MANUAL_COPY.key)
    assert_equal @user.id, receipt.payload.dig('manual_review', 'user_id')
    assert_equal 'candidate', receipt.payload.dig('manual_review', 'preferred_asset_id')
    assert_equal 'Copie choisie après examen', receipt.payload.dig('manual_review', 'comment')
    assert receipt.permitted?
    assert_equal 1, ReconciliationRun.count
    assert_not ReconciliationRuleDecision.exists?(rule_key: rule.key)
    assert_not copy.reload.active?
    assert_not @item.permitted?
  end

  test 'stale grouped forms queue no application' do
    post arbitrate_reconciliation_workbench_family_path(ReconciliationWorkbench::Rules::PREFERENCE.key),
      params: { scope_digest: 'old', choices: { @item.id.to_s => 'candidate' } }
    assert_redirected_to reconciliation_workbench_family_path(ReconciliationWorkbench::Rules::PREFERENCE.key)
    assert_equal 0, ReconciliationRun.count
    assert_equal 0, ReconciliationRuleDecision.count
  end

  private

  def decision_params
    { decision: 'approved', scope_digest: ReconciliationWorkbench::Snapshot.digest([@item.fingerprint]),
      comment: 'Même convention pour cette famille.' }
  end
end
