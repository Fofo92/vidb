require 'test_helper'
require 'minitest/mock'
require 'tmpdir'

class ReconciliationWorkbenchDiskActionTest < ActiveSupport::TestCase
  class Observer
    attr_accessor :fail_verification

    def call(entry)
      { path: entry.fetch(:path), byte_size: entry.fetch(:size), duration_minutes: 52,
        measured_duration_seconds: 3131, container: 'mkv', observed_at: Time.current,
        technical_details: { 'storage' => { 'uuid' => VideoAssets::ReconciliationVolumeGuard::UUID } } }
    end

    def verify!(_observed)
      raise ArgumentError, 'Fichier modifié avant validation' if fail_verification
    end
  end

  setup do
    language = LanguageVersion.create!(short_name: 'VF', long_name: 'Français')
    Medium.create!(short_name: 'HD', long_name: 'Disque dur')
    @record = Record.create!(french_title: 'Disque autonome', record_kind: 'standalone_video',
                            language_version: language)
    source = { format: 'vidb.video_library_inventory', version: 1, generated_at: Time.current.iso8601, roots: ['/videos'] }
    entry = { path: '/videos/Disque autonome.mkv', type: 'file', extension: '.mkv', stem: @record.french_title,
              size: 100, modified_at: 2.days.ago.iso8601 }
    observation = VideoAssets::ReconciliationReport.new(inventory: source.merge(entries: [entry])).call[:observations].sole
    payload = { 'record_id' => @record.id, 'path' => entry[:path], 'source_inventory' => source.as_json,
                'entry' => observation.merge(type: 'file', candidate: observation[:candidates].sole).as_json,
                'records' => { @record.id.to_s => ReconciliationWorkbench::Snapshot.record(@record) } }
    @item = ReconciliationWorkbench::CaseStore.propose(rule: ReconciliationWorkbench::Rules::DISK,
                                                      key: entry[:path], payload: payload)
    ReconciliationRuleDecision.create!(rule_key: @item.rule_key, rule_version: 1, decision: 'approved')
    @observer = Observer.new
    guard = Object.new
    guard.define_singleton_method(:call) { true }
    @action = ReconciliationWorkbench::DiskAction.new(observer: @observer, guard: guard)
    @observed = @observer.call(@item.payload.fetch('entry').deep_symbolize_keys)
  end

  def apply
    @action.stub(:observe, @observed) { ReconciliationWorkbench::Executor.new(disk: @action).call(@item) }
  end

  test 'real batch import commits one copy and its durable receipt without a physical worker' do
    assert_equal 'applied', apply
    asset = @record.video_assets.sole
    assert_equal '/videos/Disque autonome.mkv', asset.last_known_path
    assert_equal @record.language_version_id, asset.language_version_id
    assert_equal true, @record.reload.is_available
    assert_equal 1, ReconciliationRecordChange.where(reconciliation_case: @item).count
    assert_equal 'skipped', apply
    assert_equal 1, @record.video_assets.count
  end

  test 'a verification failure rolls back the copy and availability before a successful retry' do
    before = @record.attributes
    @observer.fail_verification = true
    assert_equal 'blocked', apply
    assert_equal 0, @record.video_assets.count
    assert_equal before, @record.reload.attributes
    assert_equal 0, ReconciliationRecordChange.count
    @observer.fail_verification = false
    assert_equal 'applied', apply
    assert_equal 1, @record.video_assets.count
  end

  test 'a new competing copy blocks without replacing it' do
    existing = @record.video_assets.create!(last_known_path: '/videos/autre.mkv')
    assert_equal 'blocked', apply
    assert_equal [existing.id], @record.video_assets.pluck(:id)
    assert_equal '/videos/autre.mkv', existing.reload.last_known_path
  end

  test 'a short animation episode can be attached with its catalogue duration preserved' do
    series = Record.create!(french_title: 'Série animée', record_kind: 'series',
                            language_version: @record.language_version)
    series.genders << Gender.create!(name: 'Animation')
    @record.update!(parent: series, record_kind: 'episode', length_in_mn: 7)
    payload = @item.payload.deep_dup
    payload['records'] = [series, @record].to_h do |record|
      [record.id.to_s, ReconciliationWorkbench::Snapshot.record(record)]
    end
    payload['entry']['candidate'].merge!('record_kind' => 'episode', 'ancestry' => @record.ancestry)
    @item = ReconciliationWorkbench::CaseStore.propose(rule: ReconciliationWorkbench::Rules::DISK,
                                                      key: @item.case_key, payload: payload)
    @observed[:duration_minutes] = 7
    @observed[:measured_duration_seconds] = 420

    assert_equal 'applied', apply
    assert_equal 7, @record.reload.length_in_mn
    assert_equal 7, @record.video_assets.sole.duration_minutes
  end

  test 'physical identity changes are detected before technical observation' do
    Dir.mktmpdir do |directory|
      path = File.join(directory, 'same.mkv')
      File.write(path, 'first')
      identity = VideoAssets::RelocationFileIdentity.call(File.lstat(path)).as_json
      File.write(path, 'another content')
      assert_raises(ArgumentError) { @action.observe('path' => path, 'identity' => identity) }
    end
  end
end
