require 'test_helper'

class ReconciliationWorkbenchCopyArbitrationTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: 'group-review@example.com', password: 'password')
    @items = (1..3).map do |id|
      ReconciliationWorkbench::CaseStore.propose(rule: ReconciliationWorkbench::Rules::PREFERENCE, key: "record:#{id}",
        payload: { 'record_id' => id, 'comparison' => { 'eligible' => false },
                   'samples' => [{ 'asset_id' => id }, { 'asset_id' => 'candidate' }], 'records' => {} })
    end
    @digest = ReconciliationWorkbench::Snapshot.digest(@items.sort_by(&:fingerprint).map(&:fingerprint))
  end

  def confirm(choices, digest: @digest)
    ReconciliationWorkbench::CopyArbitration.new(user: @user, choices: choices, scope_digest: digest).call
  end

  test 'one submission authorizes only the chosen fingerprints and leaves deferred cases unchanged' do
    assert_equal 2, confirm({ @items[0].id.to_s => 'candidate', @items[1].id.to_s => '2', @items[2].id.to_s => 'defer' })
    decision = ReconciliationRuleDecision.find_by!(rule_key: ReconciliationWorkbench::Rules::MANUAL_COPY.key)
    assert_equal 2, decision.case_fingerprints.size
    assert_equal @user.id, decision.user_id
    assert_equal 1, ReconciliationRun.count
    assert_equal ReconciliationWorkbench::Rules::MANUAL_COPY.key, ReconciliationRun.sole.rule_key
    assert_equal 'pending', @items[2].reload.status
    assert @items[2].active?
    assert_not @items[2].permitted?
  end

  test 'an invalid selected asset rolls back the entire grouped submission' do
    assert_raises(ArgumentError) { confirm({ @items[0].id.to_s => 'candidate', @items[1].id.to_s => '999' }) }
    assert_equal 0, ReconciliationRuleDecision.count
    assert_equal 0, ReconciliationRun.count
    assert_equal 3, ReconciliationCase.current.count
    assert_equal %w[pending pending pending], @items.map { |item| item.reload.status }
  end

  test 'stale scope and arbitrary case ids cannot authorize choices' do
    assert_raises(ArgumentError) { confirm({ @items[0].id.to_s => 'candidate' }, digest: 'stale') }
    assert_raises(ArgumentError) { confirm({ '9999' => 'candidate' }) }
    assert_equal 0, ReconciliationRun.count
  end

  test 'page bounds prevent confirming a case from another page' do
    28.times do |number|
      @items << ReconciliationWorkbench::CaseStore.propose(rule: ReconciliationWorkbench::Rules::PREFERENCE,
        key: "extra:#{number}", payload: @items.first.payload.merge('title' => "Extra #{number}"))
    end
    digest = ReconciliationWorkbench::Snapshot.digest(@items.sort_by(&:fingerprint).map(&:fingerprint))
    service = ->(item) do
      ReconciliationWorkbench::CopyArbitration.new(user: @user, page: 2, scope_digest: digest,
        choices: { item.id.to_s => 'candidate' }).call
    end
    assert_raises(ArgumentError) { service.call(@items.first) }
    assert_equal 0, ReconciliationRun.count
    assert_equal 1, service.call(@items.last)
    assert_equal 1, ReconciliationRun.count
    assert @items.first.reload.active?
  end

  test 'deferring every case does not enqueue any work' do
    assert_raises(ArgumentError) { confirm({ @items[0].id.to_s => 'defer' }) }
    assert_equal 0, ReconciliationRun.count
  end
end
