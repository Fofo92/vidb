require 'test_helper'
require 'minitest/mock'

class ReconciliationWorkbenchSeriesDossierTest < ActiveSupport::TestCase
  setup do
    @language = LanguageVersion.create!(short_name: 'VF', long_name: 'Français')
    @root = Record.create!(french_title: 'Série documentée', language_version: @language)
    @season = @root.children.create!(french_title: 'Saison 01', rank: 1, language_version: @language)
  end

  def identity(record)
    record.attributes.slice(*ReconciliationWorkbench::SeriesEvidence::IDENTITY)
  end

  def row(number = 1, title = 'La découverte', season = 1)
    { 'path' => "/videos/Série/Saison #{season}/S#{format('%02d', season)} E#{format('%02d', number)} - #{title}.mkv",
      'observed_title' => title, 'local_season' => season, 'local_episode' => number,
      'multi_episode_numbers' => nil, 'reference_evidence' => 'untrusted',
      'existing_season_candidates' => season == 1 ? [identity(@season)] : [],
      'reference_same_number' => [{ 'name' => title, 'season' => season, 'number' => number,
        'url' => 'https://example.org/series/episodes/1' }] }
  end

  def document(*rows)
    rows = [row] if rows.empty?
    { 'format' => 'vidb.series_structure_preparation', 'version' => 1,
      'series_group_count' => 1, 'file_count' => rows.size, 'inventory_at' => Time.current.iso8601,
      'inputs' => [{ 'filename' => 'catalogue.json', 'sha256' => 'a' * 64 }],
      'reference_attribution' => 'Sources de test', 'groups' => [{ 'name' => @root.french_title,
        'directory' => '/videos/Série', 'file_count' => rows.size, 'files' => rows,
        'proposed_existing_root' => identity(@root), 'other_same_title_roots' => [],
        'reference_url' => 'https://example.org/series' }] }
  end

  def import(source = document)
    ReconciliationWorkbench::Proposals.new.call(source).sole
  end

  def approve(item)
    ReconciliationRuleDecision.create!(rule_key: item.rule_key, rule_version: item.rule_version,
      decision: 'approved', case_fingerprints: [item.fingerprint])
  end

  test 'import proposes a whole series without creating metadata or approving either axis' do
    before = Record.count
    item = import(document(row, row(2, 'Le retour')))
    assert_equal before, Record.count
    assert_equal 2, item.payload['operations'].size
    assert_equal [], item.payload['held']
    assert_not item.permitted?
    assert_equal 'skipped', ReconciliationWorkbench::Executor.new.call(item)
    assert_equal 0, ReconciliationRuleDecision.count
    assert_equal 0, VideoAsset.count
  end

  test 'one approved series creates episodes in existing and new seasons without duplicating seasons' do
    item = import(document(row, row(1, 'Une autre aventure', 2), row(2, 'Le dénouement', 2)))
    approve(item)
    executor = ReconciliationWorkbench::Executor.new
    assert_equal 'applied', executor.call(item)
    assert_equal 'series', @root.reload.record_kind
    assert_equal 'season', @season.reload.record_kind
    assert_equal 2, @root.children.count
    new_season = @root.children.find_by!(rank: 2)
    assert_equal 'Saison 02', new_season.french_title
    assert_equal 2, new_season.children.count
    assert_equal ['episode'], @root.descendants.where.not(id: @root.children.ids).pluck(:record_kind).uniq
    assert_equal [@language.id], @root.descendants.pluck(:language_version_id).uniq
    assert_equal 3, item.reload.result['episodes'].size
    assert_equal 'skipped', executor.call(item)
    assert_equal 0, VideoAsset.count
    assert_not ReconciliationRuleDecision.exists?(rule_key: ReconciliationWorkbench::Rules::DISK.key)
  end

  test 'reuse preserves titles years protected metadata and copy ownership' do
    episode = @season.children.create!(french_title: 'La découverte', original_title: 'Discovery', rank: 1,
      year: 2020, language_version: @language, abstract: 'Avis personnel')
    asset = episode.video_assets.create!(last_known_path: '/videos/existing.mkv')
    before = episode.attributes.except('record_kind', 'updated_at')
    item = import
    assert_equal 'reuse_episode', item.payload['operations'].sole['kind']
    approve(item)
    assert_equal 'applied', ReconciliationWorkbench::Executor.new.call(item)
    assert_equal before, episode.reload.attributes.except('record_kind', 'updated_at')
    assert_equal episode.id, asset.reload.record_id
  end

  test 'source flags are ignored and generic titles multiple episodes and numbering mappings stay held' do
    wrong_title = row
    wrong_title['reference_evidence'] = 'number_and_title_agree'
    wrong_title['reference_same_number'][0]['name'] = 'Autre titre'
    wrong_number = row(2, 'Deuxième')
    wrong_number['reference_same_number'][0]['number'] = 3
    multiple = row(4, 'Quatrième')
    multiple['multi_episode_numbers'] = [4, 5]
    generic = row(6, 'Episode 6')
    item = import(document(wrong_title, wrong_number, multiple, generic))
    assert_empty item.payload['operations']
    assert_equal 4, item.payload['held'].size
    approve(item)
    assert_not item.permitted?
  end

  test 'an orphan with the same title is shown for arbitration without being moved or duplicated' do
    orphan = Record.create!(french_title: 'La découverte', rank: 1, language_version: @language)
    item = import
    assert_empty item.payload['operations']
    assert_equal [orphan.id], item.payload['held'].sole['candidate_ids']
    assert_nil orphan.reload.ancestry
  end

  test 'missing roots and competing series branches remain visible without guessing an identity' do
    source = document
    source['groups'][0]['proposed_existing_root'] = nil
    item = import(source)
    assert_nil item.payload['record_id']
    assert_empty item.payload['operations']
    source = document
    source['groups'][0]['other_same_title_roots'] = [identity(@root)]
    assert_empty import(source).payload['operations']
  end

  test 'a film collection cannot be qualified as a series' do
    @season.update!(french_title: 'Film numéro 1', record_kind: 'standalone_video')
    item = import
    assert_empty item.payload['operations']
    assert_equal 'undetermined', @root.reload.record_kind
  end

  test 'manual edits reverted after approval still block the whole series' do
    item = import
    approve(item)
    @season.update!(abstract: 'Une correction')
    @season.update!(abstract: nil)
    assert_equal 'blocked', ReconciliationWorkbench::Executor.new.call(item)
    assert_empty @season.children
    assert_equal 'undetermined', @root.reload.record_kind
  end

  test 'a newly created competing orphan blocks creation atomically' do
    item = import
    approve(item)
    Record.create!(french_title: 'La découverte', language_version: @language)
    assert_equal 'blocked', ReconciliationWorkbench::Executor.new.call(item)
    assert_empty @season.children
    assert_equal 'undetermined', @root.reload.record_kind
  end

  test 'journal failure rolls back new seasons and episodes and retry creates them once' do
    item = import(document(row(1, 'Aventure nouvelle', 2)))
    approve(item)
    before = Record.count
    ReconciliationRecordChange.stub(:create!, ->(**_args) { raise 'Journal indisponible' }) do
      assert_equal 'blocked', ReconciliationWorkbench::Executor.new.call(item)
    end
    assert_equal before, Record.count
    assert_equal 'undetermined', @root.reload.record_kind
    assert_equal 'applied', ReconciliationWorkbench::Executor.new.call(item)
    assert_equal before + 2, Record.count
    assert_equal 'skipped', ReconciliationWorkbench::Executor.new.call(item)
  end

  test 'partial catalogue identity drift is rejected before proposing anything' do
    source = document
    @season.update!(rank: 2)
    assert_raises(ArgumentError) { import(source) }
    assert_equal 0, ReconciliationCase.count
  end

  test 'approved immutable proposals survive reimport but approval cannot cover new operations' do
    source = document
    item = import(source)
    approve(item)
    original = item.payload.deep_dup
    @root.update!(abstract: 'Correction manuelle')
    assert_equal item.id, import(source).id
    assert_equal original, item.reload.payload
    assert_equal 'blocked', ReconciliationWorkbench::Executor.new.call(item)
    ReconciliationRuleDecision.find_by!(rule_key: item.rule_key).update!(decision: 'deferred')
    replacement = import(document(row, row(2, 'Le retour')))
    assert_not_equal item.id, replacement.id
    assert_not replacement.permitted?
  end

  test 'invalid sources and duplicate file paths reject the entire document' do
    source = document
    source['groups'][0]['files'][0]['reference_same_number'][0]['url'] = 'javascript:alert(1)'
    assert_raises(ArgumentError) { import(source) }
    assert_raises(ArgumentError) { import(document(row, row)) }
    assert_equal 0, ReconciliationCase.count
  end

  test 'an explicit season title allows a reviewed rank correction with no reparenting or metadata replacement' do
    @season.update!(french_title: 'Saison 02')
    episode = @season.children.create!(french_title: 'La découverte', rank: 1, language_version: @language)
    source = document(row(1, 'La découverte', 2), row(2, 'La suite', 2))
    source['groups'][0]['files'].each { |file| file['existing_season_candidates'] = [identity(@season)] }
    item = import(source)
    assert_equal [1], item.payload['operations'].map { |operation| operation['season_rank_before'] }.uniq
    approve(item)
    ancestry = episode.ancestry
    assert_equal 'applied', ReconciliationWorkbench::Executor.new.call(item)
    assert_equal 2, @season.reload.rank
    assert_equal 'Saison 02', @season.french_title
    assert_equal ancestry, episode.reload.ancestry
    assert_equal 2, @season.children.count
  end

  test 'competing seasons and conflicting episode positions are held without selecting the first' do
    @root.children.create!(french_title: 'Saison 1', rank: 1, language_version: @language)
    item = import
    assert_empty item.payload['operations']
    assert_match 'Saison', item.payload['held'].sole['reason']
  end

  test 'path numbering cannot be replaced by a trusted looking proposal label' do
    source = document
    source['groups'][0]['files'][0]['path'] = '/videos/Série/S01 E09 - La découverte.mkv'
    item = import(source)
    assert_empty item.payload['operations']
    assert_equal 1, item.payload['held'].size
  end

  test 'two physical copies for one episode do not cause a duplicate record or block unrelated episodes' do
    other = row
    other['path'] = other['path'].sub('.mkv', '.m4v')
    item = import(document(row, other, row(2, 'Le retour')))
    assert_equal 1, item.payload['operations'].size
    assert_equal 2, item.payload['held'].size
    approve(item)
    assert_equal 'applied', ReconciliationWorkbench::Executor.new.call(item)
    assert_equal [2], @season.children.pluck(:rank)
  end

  test 'the old recurring qualification rule does not approve series creation' do
    ReconciliationRuleDecision.create!(rule_key: ReconciliationWorkbench::Rules::STRUCTURE.key,
      rule_version: 1, decision: 'approved')
    item = import
    assert_not item.permitted?
    assert_equal 'skipped', ReconciliationWorkbench::Executor.new.call(item)
    assert_empty @season.children
  end

  test 'a worker pass replans after creation and chains disk work only under its independent approval' do
    item = import
    approve(item)
    disk_rule = ReconciliationWorkbench::Rules::DISK
    ReconciliationRuleDecision.create!(rule_key: disk_rule.key, rule_version: 1, decision: 'approved')
    events = []
    planner = Object.new
    planner.define_singleton_method(:call) do
      events << :plan
      record = Record.find_by(french_title: 'La découverte')
      if record
        ReconciliationWorkbench::CaseStore.propose(rule: disk_rule, key: '/videos/test.mkv', payload: {
          'record_id' => record.id, 'records' => { record.id.to_s => ReconciliationWorkbench::Snapshot.record(record) } })
      end
      {}
    end
    refresh = Object.new
    refresh.define_singleton_method(:call) { events << :scan }
    disk = Object.new
    disk.define_singleton_method(:observe) { |_payload| events << :observe; {} }
    disk.define_singleton_method(:call) { |_payload, _observed| events << :link; { 'imported' => true } }
    run = ReconciliationRun.create!(mode: 'apply')
    ReconciliationWorkbench::Worker.new(planner: planner, refresh: refresh,
      executor: ReconciliationWorkbench::Executor.new(disk: disk)).perform(run)
    assert_equal [:plan, :scan, :plan, :observe, :link, :scan], events
    assert_equal 'completed', run.reload.status
    assert_equal 1, run.summary.dig('metadata', 'applied')
    assert_equal 1, run.summary.dig('disk', 'applied')
  end
end
