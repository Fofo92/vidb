require 'test_helper'
require 'tmpdir'

class ReconciliationWorkbenchPlannerTest < ActiveSupport::TestCase
  setup do
    @directory = Dir.mktmpdir('vidb-workbench-', '/tmp')
    @language = LanguageVersion.create!(short_name: 'VF', long_name: 'Français')
    @root = Record.create!(french_title: 'Série explicite', language_version: @language)
    @season = @root.children.create!(french_title: 'Saison 01', rank: 1, language_version: @language)
    @episode = @season.children.create!(french_title: 'Un épisode', rank: 1, language_version: @language)
  end

  teardown { FileUtils.remove_entry(@directory) }

  def entry(name = 'S01 E01 - Un épisode.mkv')
    path = File.join(@directory, name)
    File.write(path, 'fixture')
    File.utime(Time.now - 172_800, Time.now - 172_800, path)
    { path: path, size: File.size(path), modified_at: File.mtime(path).iso8601, status: 'episode_candidate',
      title_evidence: 'title_match', followup_status: 'candidate',
      candidates: [{ record_id: @episode.id, record_kind: @episode.record_kind, ancestry: @episode.ancestry }] }
  end

  def followup(entries)
    { format: VideoAssets::ReconciliationFollowup::FORMAT, version: 1, inventory_at: Time.current.iso8601,
      source_inventory: { format: VideoAssets::ReconciliationReport::SOURCE_FORMAT, version: 1,
                          generated_at: Time.current.iso8601, roots: ['/videos'] }, entries: entries }
  end

  test 'one structural proposal covers the whole existing hierarchy without editing it' do
    source = followup([entry])
    planner = ReconciliationWorkbench::Planner.new(root: @directory)
    planner.call(followup: source)
    item = ReconciliationCase.current.sole
    assert_equal 'metadata', item.axis
    assert_equal 3, item.payload['roles'].size
    assert_equal 'undetermined', @episode.reload.record_kind
    assert_equal 0, VideoAsset.where(record_id: @episode.id).count
    planner.call(followup: source)
    assert_equal 1, ReconciliationCase.current.count
  end

  test 'ambiguous episode ranks do not generate a structural action' do
    @season.children.create!(french_title: 'Autre épisode', rank: 1, language_version: @language)
    ReconciliationWorkbench::Planner.new(root: @directory).call(followup: followup([entry]))
    assert_equal 0, ReconciliationCase.current.count
  end

  test 'two files for one qualified episode are never resolved by picking the first' do
    @root.update!(record_kind: 'series')
    @season.update!(record_kind: 'season')
    @episode.update!(record_kind: 'episode')
    ReconciliationWorkbench::Planner.new(root: @directory).call(followup: followup([entry('one.mkv'), entry('two.mkv')]))
    assert_equal 0, ReconciliationCase.current.where(axis: 'disk').count
  end

  test 'a qualified stable uniquely matched episode proposes a disk link without importing' do
    @root.update!(record_kind: 'series')
    @season.update!(record_kind: 'season')
    @episode.update!(record_kind: 'episode')
    ReconciliationWorkbench::Planner.new(root: @directory).call(followup: followup([entry]))
    item = ReconciliationCase.current.sole
    assert_equal 'disk', item.axis
    assert_equal @episode.id, item.payload['record_id']
    assert_equal 0, VideoAsset.where(record_id: @episode.id).count
  end

  test 'a competing candidate leaves the unique family and enters the comparison family' do
    @root.update!(record_kind: 'series')
    @season.update!(record_kind: 'season')
    @episode.update!(record_kind: 'episode')
    @episode.video_assets.create!(last_known_path: '/videos/another-copy.mkv')
    ReconciliationWorkbench::Planner.new(root: @directory).call(followup: followup([entry]))
    assert_equal 0, ReconciliationCase.current.where(rule_key: ReconciliationWorkbench::Rules::DISK.key).count
    item = ReconciliationCase.current.sole
    assert_equal ReconciliationWorkbench::Rules::PREFERENCE.key, item.rule_key
    assert_equal 2, item.payload['file_count']
    assert_equal 'blocked', item.status
    assert_equal @episode.id, item.payload.dig('candidate', 'record_id')
  end

  test 'a catalog mutation after approval blocks qualification with no partial changes' do
    ReconciliationWorkbench::Planner.new(root: @directory).call(followup: followup([entry]))
    item = ReconciliationCase.current.sole
    ReconciliationRuleDecision.create!(rule_key: item.rule_key, rule_version: item.rule_version, decision: 'approved')
    @episode.update!(french_title: 'Correction de titre')
    assert_equal 'blocked', ReconciliationWorkbench::Executor.new.call(item)
    assert_equal 'undetermined', @root.reload.record_kind
  end

  test 'replanning approved work preserves the original snapshots after a manual change' do
    planner = ReconciliationWorkbench::Planner.new(root: @directory)
    source = followup([entry])
    planner.call(followup: source)
    item = ReconciliationCase.current.sole
    decision = ReconciliationRuleDecision.create!(rule_key: item.rule_key, rule_version: 1, decision: 'approved')
    original = item.payload.deep_dup
    @episode.update!(abstract: 'Avis manuel')
    planner.call(followup: source)
    assert_equal item.id, ReconciliationCase.current.sole.id
    assert_equal original, item.reload.payload
    assert_equal 'blocked', ReconciliationWorkbench::Executor.new.call(item)
    decision.update!(decision: 'deferred')
    planner.call(followup: source)
    replacement = ReconciliationCase.current.sole
    assert_not_equal item.id, replacement.id
    assert_not replacement.permitted?
    assert_equal 'undetermined', @root.reload.record_kind
  end

  test 'short animation episodes can be qualified without changing their saved duration' do
    @root.genders << Gender.create!(name: 'Animation')
    @episode.update_column(:length_in_mn, 3)
    ReconciliationWorkbench::Planner.new(root: @directory).call(followup: followup([entry]))
    item = ReconciliationCase.current.sole
    ReconciliationRuleDecision.create!(rule_key: item.rule_key, rule_version: 1, decision: 'approved')

    assert_equal 'applied', ReconciliationWorkbench::Executor.new.call(item)
    assert_equal %w[series season episode], [@root, @season, @episode].map { |record| record.reload.record_kind }
    assert_equal 3, @episode.length_in_mn
    assert_nil @root.length_in_mn
    assert_nil @season.length_in_mn
    assert_equal 'skipped', ReconciliationWorkbench::Executor.new.call(item)
  end

  test 'an animation episode shorter than three minutes still blocks qualification atomically' do
    @root.genders << Gender.create!(name: 'Animation')
    @episode.update_column(:length_in_mn, 2)
    ReconciliationWorkbench::Planner.new(root: @directory).call(followup: followup([entry]))
    item = ReconciliationCase.current.sole
    ReconciliationRuleDecision.create!(rule_key: item.rule_key, rule_version: 1, decision: 'approved')

    assert_equal 'blocked', ReconciliationWorkbench::Executor.new.call(item)
    assert_equal %w[undetermined undetermined undetermined],
                 [@root, @season, @episode].map { |record| record.reload.record_kind }
    assert_equal 2, @episode.length_in_mn
    assert_equal 0, ReconciliationRecordChange.where(reconciliation_case: item).count
  end
  test 'an already confirmed identical path is not proposed as a new import' do
    @root.update!(record_kind: 'series')
    @season.update!(record_kind: 'season')
    @episode.update!(record_kind: 'episode')
    observed = entry
    @episode.video_assets.create!(last_known_path: observed[:path], byte_size: observed[:size], observed_at: Time.current)
    summary = ReconciliationWorkbench::Planner.new(root: @directory).call(followup: followup([observed]))
    assert_equal 1, summary['known_copies']
    assert_equal 0, ReconciliationCase.current.count
  end

end
