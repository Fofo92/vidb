require 'test_helper'
require 'tmpdir'

class ReconciliationWorkbenchWorkerTest < ActiveSupport::TestCase
  setup do
    @directory = Dir.mktmpdir('vidb-worker-', '/tmp')
    @previous_directory = ENV['VIDB_RECONCILIATION_WORKBENCH_DIR']
    ENV['VIDB_RECONCILIATION_WORKBENCH_DIR'] = @directory
  end

  teardown do
    ENV['VIDB_RECONCILIATION_WORKBENCH_DIR'] = @previous_directory
    FileUtils.remove_entry(@directory)
  end

  def item(rule, key)
    ReconciliationRuleDecision.find_or_create_by!(rule_key: rule.key, rule_version: rule.version) do |decision|
      decision.decision = 'approved'
    end
    ReconciliationWorkbench::CaseStore.propose(rule: rule, key: key, payload: { 'records' => {}, 'title' => key })
  end

  def worker(executor)
    @refreshes = 0
    @plans = 0
    planner = Object.new
    planner.define_singleton_method(:call) { { 'proposed' => 2 } }
    refresh = Object.new
    refresh.define_singleton_method(:call) { true }
    ReconciliationWorkbench::Worker.new(planner: planner, executor: executor, refresh: refresh)
  end

  test 'one pass applies both independently approved axes' do
    metadata = item(ReconciliationWorkbench::Rules::STRUCTURE, 'root:1')
    disk = item(ReconciliationWorkbench::Rules::DISK, 'file:1')
    executor = Object.new
    executor.define_singleton_method(:call) { |entry| entry.update!(status: 'applied'); 'applied' }
    run = ReconciliationRun.create!(mode: 'apply')
    worker(executor).poll
    assert_equal 'completed', run.reload.status
    assert_equal 'applied', metadata.reload.status
    assert_equal 'applied', disk.reload.status
    assert_equal 1, run.summary.dig('metadata', 'applied')
    assert_equal 1, run.summary.dig('disk', 'applied')
  end

  test 'a blocked case does not prevent independent cases from continuing' do
    first = item(ReconciliationWorkbench::Rules::DISK, 'file:1')
    second = item(ReconciliationWorkbench::Rules::DISK, 'file:2')
    executor = Object.new
    executor.define_singleton_method(:call) do |entry|
      status = entry.id == first.id ? 'blocked' : 'applied'
      entry.update!(status: status)
      status
    end
    run = ReconciliationRun.create!(mode: 'apply')
    worker(executor).poll
    assert_equal 'completed', run.reload.status
    assert_equal 'blocked', first.reload.status
    assert_equal 'applied', second.reload.status
    assert_equal 1, run.summary.dig('disk', 'blocked')
  end

  test 'stop requests finish the current operation and leave the remainder pending' do
    first = item(ReconciliationWorkbench::Rules::DISK, 'file:1')
    second = item(ReconciliationWorkbench::Rules::DISK, 'file:2')
    run = ReconciliationRun.create!(mode: 'apply')
    executor = Object.new
    executor.define_singleton_method(:call) do |entry|
      entry.update!(status: 'applied')
      run.update!(stop_requested: true)
      'applied'
    end
    worker(executor).poll
    assert_equal 'stopped', run.reload.status
    assert_equal 'applied', first.reload.status
    assert_equal 'pending', second.reload.status
  end

  test 'an interrupted running case is retried and completed work is not repeated' do
    done = item(ReconciliationWorkbench::Rules::DISK, 'file:1')
    done.update!(status: 'applied')
    interrupted = item(ReconciliationWorkbench::Rules::DISK, 'file:2')
    interrupted.update!(status: 'running')
    calls = []
    executor = Object.new
    executor.define_singleton_method(:call) { |entry| calls << entry.id; entry.update!(status: 'applied'); 'applied' }
    run = ReconciliationRun.create!(mode: 'apply', status: 'running')
    worker(executor).poll
    assert_equal [interrupted.id], calls
    assert_equal 'completed', run.reload.status
    assert_equal 'applied', done.reload.status
  end

  test 'a requested stop is not undone by a newer scan' do
    path = File.join(@directory, 'current.json')
    File.write(path, '{}')
    previous = ENV['VIDB_RECONCILIATION_FOLLOWUP_PATH']
    ENV['VIDB_RECONCILIATION_FOLLOWUP_PATH'] = path
    run = ReconciliationRun.create!(mode: 'apply', status: 'stopped', created_at: 1.hour.ago)
    assert_equal({ idle: true }, worker(Object.new).poll)
    assert_equal 'stopped', run.reload.status
    assert_equal 1, ReconciliationRun.count
  ensure
    ENV['VIDB_RECONCILIATION_FOLLOWUP_PATH'] = previous
  end

  test 'the scan published during a completed refresh does not enqueue an endless refresh loop' do
    path = File.join(@directory, 'current.json')
    File.write(path, '{}')
    previous = ENV['VIDB_RECONCILIATION_FOLLOWUP_PATH']
    ENV['VIDB_RECONCILIATION_FOLLOWUP_PATH'] = path
    ReconciliationRun.create!(mode: 'refresh', status: 'completed', created_at: 1.hour.ago, finished_at: Time.current)
    assert_equal({ idle: true }, worker(Object.new).poll)
    assert_equal 1, ReconciliationRun.count
  ensure
    ENV['VIDB_RECONCILIATION_FOLLOWUP_PATH'] = previous
  end

  test 'obsolete candidate entries for known copies trigger one scan before the final plan' do
    calls = 0
    refreshes = 0
    planner = Object.new
    planner.define_singleton_method(:call) { calls += 1; { 'known_copies' => calls == 1 ? 1 : 0 } }
    refresh = Object.new
    refresh.define_singleton_method(:call) { refreshes += 1 }
    run = ReconciliationRun.create!(mode: 'apply')
    ReconciliationWorkbench::Worker.new(planner: planner, refresh: refresh).poll
    assert_equal 1, refreshes
    assert_equal 2, calls
    assert_equal 'completed', run.reload.status
  end

  test 'an old completed run does not cause repeated processing of a scan already handled by the latest run' do
    path = File.join(@directory, 'current.json')
    File.write(path, '{}')
    previous = ENV['VIDB_RECONCILIATION_FOLLOWUP_PATH']
    ENV['VIDB_RECONCILIATION_FOLLOWUP_PATH'] = path
    ReconciliationRun.create!(mode: 'apply', status: 'completed', created_at: 2.hours.ago, finished_at: 1.hour.ago)
    ReconciliationRun.create!(mode: 'apply', status: 'completed', created_at: 5.minutes.ago, finished_at: Time.current)
    2.times { assert_equal({ idle: true }, worker(Object.new).poll) }
    assert_equal 2, ReconciliationRun.count
  ensure
    ENV['VIDB_RECONCILIATION_FOLLOWUP_PATH'] = previous
  end

  test 'the latest explicit stop is respected even if an older completed run exists' do
    path = File.join(@directory, 'current.json')
    File.write(path, '{}')
    previous = ENV['VIDB_RECONCILIATION_FOLLOWUP_PATH']
    ENV['VIDB_RECONCILIATION_FOLLOWUP_PATH'] = path
    ReconciliationRun.create!(mode: 'apply', status: 'completed', created_at: 2.hours.ago, finished_at: 1.hour.ago)
    ReconciliationRun.create!(mode: 'apply', status: 'stopped', created_at: 5.minutes.ago)
    assert_equal({ idle: true }, worker(Object.new).poll)
    assert_equal 2, ReconciliationRun.count
  ensure
    ENV['VIDB_RECONCILIATION_FOLLOWUP_PATH'] = previous
  end

  test 'a manual resumption after an old stop permits a newer scan to trigger automatic processing' do
    path = File.join(@directory, 'current.json')
    File.write(path, '{}')
    previous = ENV['VIDB_RECONCILIATION_FOLLOWUP_PATH']
    ENV['VIDB_RECONCILIATION_FOLLOWUP_PATH'] = path
    ReconciliationRun.create!(mode: 'apply', status: 'stopped', created_at: 2.hours.ago)
    ReconciliationRun.create!(mode: 'apply', status: 'completed', created_at: 1.hour.ago, finished_at: 30.minutes.ago)
    worker(Object.new).poll
    assert_equal 3, ReconciliationRun.count
    assert_equal 'completed', ReconciliationRun.order(:id).last.status
  ensure
    ENV['VIDB_RECONCILIATION_FOLLOWUP_PATH'] = previous
  end

  test 'an explicit refresh scans before planning even with no known copy candidates' do
    calls = []
    planner = Object.new
    planner.define_singleton_method(:call) { calls << :plan; {} }
    refresh = Object.new
    refresh.define_singleton_method(:call) { calls << :scan }
    run = ReconciliationRun.create!(mode: 'refresh')
    ReconciliationWorkbench::Worker.new(planner: planner, refresh: refresh).poll
    assert_equal [:scan, :plan], calls
    assert_equal 'completed', run.reload.status
  end

  test 'preferences are counted separately from imported disk copies' do
    preference = item(ReconciliationWorkbench::Rules::PREFERENCE, 'record:1')
    preference.update!(payload: { 'records' => {}, 'comparison' => { 'eligible' => true } })
    executor = Object.new
    executor.define_singleton_method(:call) { |entry| entry.update!(status: 'applied'); 'applied' }
    run = ReconciliationRun.create!(mode: 'apply')
    worker(executor).poll
    assert_equal 1, run.reload.summary.dig('preferences', 'applied')
    assert_equal 0, run.summary.dig('disk', 'applied').to_i
  end

  test 'a second worker cannot enter while the execution lock is held' do
    File.open(File.join(@directory, 'worker.lock'), 'w') do |file|
      file.flock(File::LOCK_EX)
      assert_equal({ busy: true }, worker(Object.new).poll)
    end
  end
end
